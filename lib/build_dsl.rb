require 'build_maestro/svn.rb'
require 'uri'

def reset_dsl
  $version = nil
  $build_name = 'anonymous'
  $dependencies = []
  $svn_user = nil
  $svn_pass = nil
end


# @param [String] vers the version to be used and injected into the root projects info.plist
def build_version (vers)
  $version = vers
end



def build_name ( name ) 
  $build_name = name unless name.nil?
end


#
# Set a global SVN user account to use when talking with repositories
# Optionally, if no password is given, we will look in the local keychain
# for a generic password matching the given account name, matching service name build_maestro
#
def set_svn_user( user, pass=nil )
  raise "you must specify an svn user" if user.nil?

  if pass.nil?
    # lookup = %x[ security find-generic-password -g -s build_maestro -a #{user} 2>&1 ]
    # lookup = spawn( "security find-generic-password -g -s build_maestro -a #{user}", :err=>:out)

    r,w = IO.pipe
    pid = spawn( "security find-generic-password -g -s build_maestro -a #{user}", 
                 {:out=>:close,:err=>w})
    w.close
    lookup = r.read # result should be a string, or nil
    r.close

    raise "Unable to find a password for #{user}" if lookup.nil?
    
    lookup.each_line do |line|
      match = line.match( /^password: (.+)/)
      unless match.nil?
        unless match.captures.nil? || match.captures.length < 1
          password = match.captures.first
          pass = password.gsub( '\"', '')
          break
        end
      end
    end    
  end

  raise "you must specify a password or store one in your keychain" if pass.nil?
  
  $svn_user = user
  $svn_pass = pass
end



# @param [String] src_root a path to the root of a SVN project that has trunk,tags,branches subdirs
# @param [String] tag_name the name of the tag to create using the specified src root (default is to use the svn revision)
# @return [String] the full path to the newly created tag
#
#
# We support two syntaxes...the previous one. And this one.
# This one is kind of complicated.
# 1) First, is the srcpath. This is a full URL to the source that we are tagging. However, 
#    there are a few options. If no :tagpath is given, we'll use the srcpath and append /trunk to
#    get the full src path URL, and then append tags/rXXXX to make the tag.
#    If there is a :tagpath given, then we'll just do a straight svn copy from :srcpath to :tagpath.
# 2) By default, we will checkout the code to a path in workspace identified by :dest. But if there
#    is no :dest, we'll use the basename of the :srcpath to use as :dest.
# 3) If :checkout => false, then no :dest is necessary
#
#def make_tag (src_root, tag_name=nil, destination=nil)
def make_tag ( *args )
  actual_tag_path = nil
  
  msg = "making tag for #{$build_name} #{$version}"
     

  #
  # This is the new 1.1.0 logic. Preferred, and it paves the way for more features
  # in the future.
  #
  if args.first.instance_of?( Hash)
    args = args.first
    
    srcpath = args[:srcpath]
    raise "You must specify a :srcpath" if srcpath.nil?

    tagpath = args[:tagpath]
    if tagpath.nil?
      svn_client = BuildMaestro::SVN.new( srcpath, $svn_user, $svn_pass)    
      actual_tag_path = svn_client.tag( nil, msg) # will make tag using svn revision
    else
      svn_client = BuildMaestro::SVN.new( nil, $svn_user, $svn_pass)    
      actual_tag_path = svn_client.copy( srcpath, tagpath, msg) 
    end
    
    checkout = args[:checkout]
    unless checkout.nil? && checkout == false
      dest = args[:destination]
      if dest.nil?
        uri = URI( src_root)
        File.basename( uri.path)
        dest = File.basename( uri.path)
      end
      
      svn_client.checkout( actual_tag_path, dest)                    
      
    end
    

  end


  
  #
  # This is the 1.0.0 logic. deprecated.
  #
  if args.instance_of?( Array)
    
    raise "Invalid usage of make_tag" if args.nil? || args.count <= 0
    
    src_root = args.first
    
    case args.count
    when 3
      tag_name = args[1]
      destination = args[2]
    when 2
      tag_name = args[1]
      destination = nil
    when 1
      tag_name = nil
      destination = nil        
    end
    
    svn_client = BuildMaestro::SVN.new( src_root, $svn_user, $svn_pass)
    actual_tag_path = svn_client.tag( tag_name, msg)

    if destination.nil?
      uri = URI( src_root)
      File.basename( uri.path)
      destination = File.basename( uri.path)
    end
        
    svn_client.checkout( actual_tag_path, destination )        
  end

  actual_tag_path
end



def dependency (src_path, destination)
  raise "a source path must be specified in a dependency" if src_path.nil?
  raise "a destination must be specified for each dependenciy" if destination.nil?

  $dependencies.push([src_path, destination])
end


#
# now do the actual work
# we pass in a couple things to the block, but the commands have access to environment variables too
#  we pass in the build version as the first block parameter
#  second, we pass in the workspace directory
#
def build
  raise "You must specify a build_version" if $version.nil?

  svn_client = BuildMaestro::SVN.new( nil, $svn_user, $svn_pass)

  $dependencies.each do |dep|
    svn_client.checkout( dep[0], dep[1])
  end

  workspace = ENV['PWD']

  yield( $version, workspace) if block_given?
end

#
# Run a shell command with some nice features
#
def run ( cmd )

  return if cmd.nil?
  
  workspace = ENV['PWD']
  
  system( "echo \"RUNNING: #{cmd}\" >> #{workspace}/bm.log")
  the_cmd = cmd << " 2>&1 | tee -a #{workspace}/bm.log"
  system( the_cmd)

  raise "error running command: #{cmd}" unless $?.success?
  
end



def process_build_spec ( bm_file )
  raise "no build spec file" if bm_file.nil?
  raise "build spec file does not exist: #{bm_file}" unless File.exists?( bm_file)

  load( bm_file)
end

