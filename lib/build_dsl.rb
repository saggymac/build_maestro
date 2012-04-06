require 'build_maestro/svn.rb'
require 'uri'
require 'pry'

def reset_dsl
  $version = nil
  $root_project = nil
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
# for a generic password matching the given account name.
#
def set_svn_user( user, pass=nil )
  raise "you must specify an svn user" if user.nil?

  if pass.nil?
    lookup = %x[ security find-generic-password -g -s svn -a #{user} 2>&1 ]
    raise "Unable to find a password for #{user}" if lookup.nil?
    
    lookup.each_line do |line|
      puts line
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
# @return nil
def root_project (src_root)
  $root_project = src_root
end


# @param [String] src_root a path to the root of a SVN project that has trunk,tags,branches subdirs
# @param [String] tag_name the name of the tag to create using the specified src root (default is to use the svn revision)
# @return [String] the full path to the newly created tag
def make_tag (src_root, tag_name=nil, destination=nil)
  msg = "making tag for #{$build_name} #{$version}"
  svn_client = BuildMaestro::SVN.new( src_root, $svn_user, $svn_pass)
  tag_path = svn_client.tag( tag_name, msg)
  
  if destination.nil?
    uri = URI( src_root)
    File.basename( uri.path)
    destination = File.basename( uri.path)
  end
  
  svn_client.checkout( tag_path, destination )
  
  tag_path
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
  raise "You must specify a root_project" if $root_project.nil?

  app_tag = make_tag $root_project, $version, 'app'

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

