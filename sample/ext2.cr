# Showcases an Ext2 FUSE driver.  The driver only implements read-only access.
#
# To run this example:
#  1. Have FUSE installed and a Ext2 formatted image.
#     See `sample/README.md` on how to do this if unsure.
#  2. Create a directory as mountpoint:
#       $ mkdir mnt
#  3. Start the example, giving the image path as first argument:
#       $ crystal run sample/simple.cr -- ext2.img -d -s -f mnt
#  4. Now inspect your mounted folder
#  5. Stop the program either through Ctrl-C, or by doing
#       $ fusermount -u mnt

require "../src/fuse"
require "./ext2/*"

class Ext2Fs < Fuse::FileSystem
  def initialize(@reader : Ext2::Reader)
    super()
  end

  def getattr(path)
    inode = @reader.resolve_inode(path)
    # pp path, inode
    return -Errno::ENOENT if inode.nil?
    inode_stat(inode)
  end

  def read(path, handle, buffer, offset, fi)
    inode = @reader.resolve_inode(path)
    return -Errno::ENOENT if inode.nil?
    return -Errno::EISDIR if inode.permissions.directory?

    read_buf = @reader.read_inode(inode, offset.to_u64, buffer.size.to_u64)
    buffer.copy_from(read_buf)
    read_buf.size.to_i32
  end

  def readdir(path, handle, offset, fi)
    inode = @reader.resolve_inode(path)
    return -Errno::ENOENT if inode.nil?
    return -Errno::ENOTDIR unless inode.permissions.directory?

    @reader.read_directory(inode).map do |name, entry|
      entry_inode = @reader.read_inode(entry.inode)
      { name, inode_stat(entry_inode) }
    end
  end

  private def timespec(timestamp)
    ts = LibC::Timespec.new
    ts.tv_sec = LibC::TimeT.new(timestamp)
    ts
  end

  private def inode_stat(inode)
    stat = LibC::Stat.new
    stat.st_atim = timespec inode.access_time
    stat.st_ctim = timespec inode.created_time
    stat.st_mtim = timespec inode.modified_time
    stat.st_nlink = inode.hard_links
    stat.st_mode = inode.permissions.value
    stat.st_uid = inode.owner_uid
    stat.st_gid = inode.owner_gid
    stat.st_size = @reader.inode_file_size(inode) if inode.permissions.regular?
    stat
  end
end

image_path = ARGV.shift
reader = Ext2::Reader.new(File.open(image_path, "r"))
Ext2Fs.new(reader).run!
