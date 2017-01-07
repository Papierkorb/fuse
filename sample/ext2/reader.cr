module Ext2
  # Crude, but functional, reader for Ext2 filesystems.  Only implements
  # read-only access.
  class Reader
    ROOT_DIRECTORY_INODE = 2
    SUPERBLOCK_OFFSET = 1024

    getter superblock : Native::Superblock
    getter extended_superblock : Native::ExtendedSuperblock?
    getter reserved_inodes : UInt32 = 10u32
    getter inode_size : UInt32 = 128u32
    getter block_groups : Array(Native::BlockGroupDescriptor)
    getter block_size : UInt64

    @indir_block_size : UInt32
    @indir_block_shift : UInt32
    @indir_block_mask : UInt32

    def initialize(@handle : IO::FileDescriptor)
      @handle.seek SUPERBLOCK_OFFSET

      @superblock = Native::Superblock.new
      @handle.read_fully struct_bytes(@superblock, Native::Superblock)

      if @superblock.version_major >= 1
        ext = Native::ExtendedSuperblock.new
        @handle.read_fully struct_bytes(ext, Native::ExtendedSuperblock)
        @extended_superblock = ext
        @inode_size = ext.inode_size.to_u32
        @reserved_inodes = ext.first_non_reserved_inode - 1
      end

      @block_size = 1024u64 << @superblock.block_size
      @indir_block_size = @block_size.to_u32 / sizeof(UInt32)
      @indir_block_mask = @indir_block_size - 1
      @indir_block_shift = @indir_block_mask.popcount.to_u32 + 1

      gdt_block = (@block_size == 1024) ? 2 : 1
      @handle.seek @block_size * gdt_block

      group_count, rem = @superblock.block_count.divmod @superblock.blocks_per_group
      group_count += 1 if rem > 0

      @block_groups = Array(Native::BlockGroupDescriptor).new(group_count) do
        bgd = Native::BlockGroupDescriptor.new
        @handle.read_fully struct_bytes(bgd, Native::BlockGroupDescriptor)
        bgd
      end
    end

    def read_block(block)
      read_block block, Bytes.new(@block_size)
    end

    def read_block(block, buffer)
      @handle.seek block * @block_size
      @handle.read buffer
      buffer
    end

    def read_root_inode
      read_inode ROOT_DIRECTORY_INODE
    end

    def read_inode(inode)
      per_block = @block_size.to_u32 / @inode_size
      group_idx = (inode.to_u32 - 1) / @superblock.inodes_per_group
      inner_idx = inode.to_u32 - 1 - group_idx * @superblock.inodes_per_group
      block_off, block_idx = inner_idx.divmod per_block

      table_block = @block_groups[group_idx].inode_table_address + block_off
      file_pos = table_block * @block_size + block_idx * @inode_size

      buffer = Bytes.new(instance_sizeof(Native::Inode))
      @handle.seek file_pos
      @handle.read_fully buffer

      buffer.pointer(buffer.size).as(Native::Inode*).value
    end

    def inode_file_size(inode : Native::Inode)
      size = inode.size_lo.to_u64

      if !inode.permissions.directory? && @superblock.version_major >= 1
        size |= inode.size_hi.to_u64 << 32
      end

      size
    end

    private def read_redirection_block(block)
      data = read_block(block)
      data.pointer(data.size).as(UInt32*).to_slice(data.size / sizeof(UInt32))
    end
    #
    # private def read_inode_block_redirected(ptr_block, block, depth)
    #   raise "Tried to read from unallocated redirection block" if ptr_block == 0
    #   addresses = read_redirection_block(ptr_block)
    #
    #   if depth < 1
    #     addresses[block]
    #   else
    #     next_ptr = block.to_u64 >> @indir_block_shift
    #     inner = block.to_u64 & @indir_block_mask
    #     read_inode_block_redirected(addresses[next_ptr], inner, depth - 1)
    #   end
    # end

    private def find_indirected_block(addresses, path)
      path.reduce(addresses) do |addr, ptr|
        block = read_block(addr[ptr])
        block.pointer(block.size).as(UInt32*).to_slice(block.size / sizeof(UInt32))
      end
    end

    private def inode_block_path(block)
      per_indir = @indir_block_size.to_u64

      normalized = block - 12
      if block < 12
        { nil, block }
      elsif normalized < per_indir
        { { 12 }, normalized }
      elsif normalized < per_indir * per_indir
        first, second = normalized.divmod(per_indir)
        # We -1 as `normalized` is actually offset by 1x `per_indir`.
        { { 13, first - 1 }, second }
      else
        first, inner = normalized.divmod(per_indir * per_indir)
        first -= 1
        second, third = inner.divmod(per_indir)
        { { 14, first, second - 1 }, third }
       end
    end

    private def find_inode_block(inode : Native::Inode, block)
      file_offset = @block_size.to_u64 * block.to_u64
      if file_offset > inode_file_size(inode)
        raise ArgumentError.new("Trying to read block beyond file size")
      end

      path, idx = inode_block_path(block)
      list = inode.direct_ptr
      list = find_indirected_block inode.direct_ptr, path if path
      list[idx]
    end

    private def read_inode_blocks(inode : Native::Inode, blocks)
      block_size = @block_size
      buffer = Bytes.new blocks.size * block_size

      blocks.each_with_index do |block, idx|
        slice = buffer[idx * block_size, block_size]
        read_block find_inode_block(inode, block), slice
      end

      buffer
    end

    def read_inode(inode : Native::Inode, offset : UInt64, length : UInt64)
      total_size = inode_file_size(inode)
      raise IndexError.new("Read out of bounds: #{offset} > #{total_size}") if offset > total_size
      length = { length, total_size - offset }.min

      first_block = offset / @block_size
      last_block = (offset + length) / @block_size
      blocks = read_inode_blocks(inode, first_block..last_block)

      off = offset % @block_size
      blocks[off, length]
    end

    def read_inode(inode : Native::Inode)
      read_inode(inode, 0u64, inode_file_size(inode))
    end

    def read_directory(inode : Native::Inode) : Array(Tuple(String, Native::DirectoryEntry))
      buffer = read_inode(inode)
      entries = Array(Tuple(String, Native::DirectoryEntry)).new

      long_name = true
      if ext_superblock = @extended_superblock
        long_name = !ext_superblock.required_features.directory_entry_has_type_field?
      end

      while buffer.size > instance_sizeof(Native::DirectoryEntry)
        entry = buffer.pointer(instance_sizeof(Native::DirectoryEntry)).as(Native::DirectoryEntry*).value

        break if entry.total_size < instance_sizeof(Native::DirectoryEntry)

        name_len = entry.name_len.to_u32
        name_len |= entry.type.to_u32 << 8 if long_name
        name = String.new(buffer[instance_sizeof(Native::DirectoryEntry), name_len])

        entries << { name, entry } unless entry.inode == 0
        buffer += entry.total_size
      end

      entries
    end

    # Resolves an `Native::Inode` by *path*.  If not found, returns `nil`.
    def resolve_inode(path : String) : Native::Inode?
      path.split('/').reject(&.empty?).reduce(read_root_inode.not_nil!) do |parent, child_name|
        raise "Parent is not a directory" unless parent.permissions.directory?
        _, child = read_directory(parent).find({ nil, nil }){|name, _| name == child_name}

        return nil if child.nil?
        read_inode(child.inode)
      end
    end

    private macro struct_bytes(variable, type)
      pointerof({{ variable }}).as(UInt8*).to_slice(instance_sizeof({{ type }}))
    end
  end
end
