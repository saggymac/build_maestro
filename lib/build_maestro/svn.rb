

module BuildMaestro

  class SVN
    attr_accessor :root
    attr_accessor :user
    attr_accessor :pass

    # @param [String] root The SVN root path (probably a URL), under which trunk, tags, and branches live
    def initialize ( root, user=nil, pass=nil )
      @root = root
      @user = user
      @pass = pass
    end

    def path_exists?( src )
      return false if src.nil?
      
      cmd = "svn info --non-interactive --username #{@user} --password #{@pass} #{src}"
      
      begin
        result = %x[ #{cmd} ]
      rescue
      end

      return false if result.nil?
      

      exists = false
      
      result.each_line { |line|
        line.chop!

        m = line.match( /^Path: / )
        unless m.nil?
          exists = true
          break
        end
      }
      
      exists
    end
    

    def info( src )
      cmd = "svn info --non-interactive --username #{@user} --password #{@pass} #{src}"
      result = %x[ #{cmd} ]
      raise "Error executing: svn info" unless $?.success?

      result
    end


    def copy( src, dest, message )
      
      return dest if path_exists?( dest)
      
      message = 'empty' if message.nil?
      cmd = "svn copy --non-interactive --username #{@user} --password #{@pass} -m \'#{message}\' \'#{src}\' \'#{dest}\'"
      puts "#{cmd}"
      result = %x[ #{cmd} ]

      raise "Error executing: svn copy" unless $?.success?

      dest
    end


    def determine_revision
      info_resp = info( @root)
      raise "Cannot query for svn info at #{@root}" if info_resp.nil?

      revision = nil

      info_resp.each_line { |line|
        line.chop!

        m = line.match( /^Revision: (\d+)/ )
        unless m.nil? || m.captures.length < 1
          revision = m[1]
          break
        end

      }

      revision
    end


    # @param [String] tag_name The name to give the tag in SVN; will try to determine the current svn
    #  revision if no tag name is given
    # @return [String] the full path to the new tag
    def tag ( tag_name, message )

      raise "You must specify a root before you can tag" if @root.nil?

      if tag_name.nil?
        revision = determine_revision        
        raise "Unable to determine revision" if revision.nil?
        tag_name = "r#{revision}"
      end

      src = @root + "/trunk"
      dest = @root + "/tags/#{tag_name}"

      copy src, dest, message

      dest
    end


    def branch ( branch_name, message )
      src = @root + "/trunk"
      dest = @root + "/branches/#{branch_name}"

      copy src, dest, message

      nil
    end


    # @param [String] path checkout the project identified by path (relative to the SVN root for this instance)
    # @param [String] dest the path on the local filesystem into which we should checkout
    # @return nil
    #
    def checkout( path, dest )      
      cmd = "svn checkout --non-interactive --username #{@user} --password #{@pass} \'#{path}\' \'#{dest}\'"
      result = %x[ #{cmd} ]

      raise "Error executing: svn checkout" unless $?.success?

      nil
    end




  end

end
