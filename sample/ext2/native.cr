module Ext2
  # See http://www.nongnu.org/ext2-doc/ext2.html
  lib Native
    SIGNATURE = 0xEF55u16

    enum FileSystemState : UInt16
      Clean = 1
      Errors = 2
    end

    enum ErrorHandlingMethod : UInt16
      Ignore = 1 # Ignore errors
      RemountRo = 2 # Remount read-only
      Panic = 3 # Kernel panic
    end

    # Creator OS ids.  Not big of a deal if we don't know.
    enum CreatorId : UInt32
      Linux = 0
      GnuHurd = 1
      Masix = 2
      FreeBsd = 3
      OtherLites = 4
    end

    @[Packed]
    struct Superblock
      inode_count : UInt32
      block_count : UInt32
      superuser_blocks : UInt32
      unallocated_blocks : UInt32
      unallocated_inodes : UInt32
      superblock_block : UInt32
      block_size : UInt32 # * 1024
      fragment_size : UInt32 # * 1024
      blocks_per_group : UInt32
      fragments_per_group : UInt32
      inodes_per_group : UInt32
      last_mount : UInt32 # UNIX Timestamp
      last_write : UInt32 # UNIX Timestamp
      mount_count : UInt16 # Times mounted since last fsck
      mounts_per_check : UInt16
      signature : UInt16 # == SIGNATURE
      fs_state : FileSystemState
      error_response : ErrorHandlingMethod
      version_minor : UInt16
      time_last_check : UInt32 # UNIX Timestamp
      check_interval : UInt32 # Seconds between forced checks
      creator_os : UInt32 # OS from this FS was created
      version_major : UInt32
      superuser_uid : UInt16 # UID which can use reserved blocks
      superuser_gid : UInt16 # GID which can use reserved blocks
    end

    @[Flags]
    enum OptionalFeature : UInt32
      PreallocateBlocks = 0x01
      AfsInodesExist = 0x02
      HasJournal = 0x04 # Ext3 journaling
      ExtendedAttributes = 0x08 # Inodes have extended attributes
      Resizable = 0x10 # Filesystem can be enlarged
      HashIndex = 0x20 # Directories use a hash index
    end

    @[Flags]
    enum RequiredFeature : UInt32
      Compressed = 0x01
      DirectoryEntryHasTypeField = 0x02
      ReplayJournal = 0x04
      ExternalJournal = 0x08
    end

    @[Flags]
    enum WriteFeature : UInt32
      Sparse = 0x01
      LargeFiles = 0x02 # 64-bit for file sizes
      BinaryTreeDirectory = 0x04
    end

    # Only exists if `Superblock#version_major` is greater-equal 1.
    @[Packed]
    struct ExtendedSuperblock
      first_non_reserved_inode : UInt32 # Else assume "11"
      inode_size : UInt16 # Else assume "128"
      this_block_group : UInt16 # If this superblock is a backup, which block group it's part of
      optional_features : OptionalFeature # Optional features to use
      required_features : RequiredFeature # Required features to use
      write_features : WriteFeature # Required features to write, else mount read-only
      filesystem_id : UInt8[16] # Also what `blkid` outputs
      volume_name : UInt8[16] # NULL-terminated label
      last_mount_path : UInt8[64] # Path this was last mounted on
      compression_algorithm : UInt64 # If set in the `#required_features`
      file_block_preallocation : UInt8 # Number of blocks to preallocate for files
      directory_block_preallocation : UInt8 # Number of blocks to preallocate for directories
      padding1 : UInt16

      journal_id : UInt8[16] # Journal ID
      journal_inode : UInt32
      journal_device : UInt32
      orphan_inode_head : UInt32 # Head of orphaned inode list

      hash_seed : UInt32[4]
      hash_version : UInt8
      padding2 : UInt8[3]

      default_mount_options : UInt32
      first_meta_bg : UInt32
    end

    @[Packed]
    struct BlockGroupDescriptor
      block_map_address : UInt32
      inode_map_address : UInt32
      inode_table_address : UInt32
      unallocated_blocks : UInt16
      unallocated_inodes : UInt16
      directory_count : UInt16
      unused : UInt8[14]
    end

    @[Flags]
    enum Permission : UInt16
      Fifo = 0x1000
      CharDevice = 0x2000
      Directory = 0x4000
      BlockDevice = 0x6000
      Regular = 0x8000
      Symbolic = 0xA000
      Socket = 0xC000

      OtherExecute = 0x0001
      OtherWrite = 0x0002
      OtherRead = 0x0004
      GroupExecute = 0x0008
      GroupWrite = 0x0010
      GroupRead = 0x0020
      UserExecute = 0x0040
      UserWrite = 0x0080
      UserRead = 0x0100

      StickyBit = 0x0200
      SetGid = 0x0400
      SetUid = 0x0800
    end

    @[Flags]
    enum Flag : UInt32
      SecureDelete = 0x01 # Unused
      KeepCopy = 0x02 # Unused
      UseCompression = 0x04 # Unused
      SyncWrite = 0x08 # Don't cache data
      Immutable = 0x10
      AppendOnly = 0x20
      NoDump = 0x40
      NoAccessTime = 0x80
      HashIndexedDirectory = 0x10000
      AfsDirectory = 0x20000
      JournalFileData = 0x40000
    end

    @[Packed]
    struct Inode
      permissions : Permission
      owner_uid : UInt16
      size_lo : UInt32 # Lower 32-bits of the data size
      access_time : UInt32 # UNIX timestamp
      created_time : UInt32 # UNIX timestamp
      modified_time : UInt32 # UNIX timestamp
      deletion_time : UInt32 # UNIX timestamp
      owner_gid : UInt16
      hard_links : UInt16 # Count of hard links to here.  If 0, deallocate
      data_sector_count : UInt32 # Count of *sectors* the data uses
      flags : Flag
      os1 : UInt32 # OS specific value 1
      direct_ptr : UInt32[15] # First 12 blocks of the file
      # singly_indirect_blocks : UInt32
      # doubly_indirect_blocks : UInt32
      # triply_indirect_blocks : UInt32
      generation_number : UInt32
      acl_block : UInt32
      size_hi : UInt32
      fragment_block_address : UInt32
      os2 : UInt8[12] # OS specific values 2
    end

    enum TypeIndicator : UInt8
      Unknown = 0
      Regular = 1
      Directory = 2
      CharDevice = 3
      BlockDevice = 4
      Fifo = 5
      Socket = 6
      Symlink = 7
    end

    @[Packed]
    struct DirectoryEntry
      inode : UInt32
      total_size : UInt16
      name_len : UInt8

      # If `RequiredFeature::DirectoryEntryHasTypeField` is set, this is a type as
      # in `TypeIndicator`.  Else, this is the upper 8 bits of the name length.
      type : UInt8

      # name : UInt8[name_len]
      # OR
      # name : UInt8[type << 8 | name_len]
    end
  end
end
