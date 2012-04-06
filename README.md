# iOS Build Maestro #
*Scott A. Guyer*

This project is a tool that wraps the various build steps that I commonly take when generating iPhone builds. At a high level, it starts with a build specification that is a YAML document. This tool will then operation on that build spec to handle things like:

1. Tag various SCM elements from specified source trees
2. Optionally checkout those new tags to a working area
3. Make any more checkouts as specified into the workspace
4. Do the build
5. Bundle up any necessary build assets
6. Publish those build assets

## Why not just use Hudson/Jenkins? ##

I started off using those for years. But it never quite fit. Many of my concepts are similar to what you'd find in Hudson/Jenkins, but in the end, an automated build system is not a CI server. For example, we have no need watch an SVN repository for changes to automatically trigger a build and test cycle. Rather, for the automated build process, the primary objective is to ***remove the human element*** and make the rather tedious build process bearable and repeatable.

Secondly, I was looking for an excuse to do more ruby development, and even dabble with a DSL.

## So what do these build specs look like? ##

Might be the easiest way to understand how this works, is to see an example build spec.


***

	build_name 'supercool-project'
	build_version '2.0.5.0'
	
	# Set some global params required to access your SVN server
	# PARAMS:
	# user - required
	# (optional) - password. If you don't specify, we will look in the mac keychain using 
	#     a generic password and the given userid	
	set_svn_user 'svnuser'


	# tag work - to take any other dependency projects
	# will automatically checkout too
	# PARAMS:
	# src_root a path to the root of a SVN project that has trunk,tags,branches subdirs
	# (optional) tag_name the name of the tag to create using the specified src root (default is to use the svn revision)
	# (optional) a destination path to checkout to if provided (default is basename of url)	
	make_tag 'http://www.svnserver.com/path/to/project/root'


	# build dependencies
	# dependency 'srcpath' 'dest'
	dependency 	'http://www.svnserver.com/path/to/project', "project"


	# now do the actual work
	# the workspace will be the current working directory
	# version (from above) will be passed in to the block as well
	#
	# You can put anything you want here, ruby, but most commonly, shell commands via...
	#   %x[ cmd with params here ]
	# Or perhaps better, 
	#   run "cmd here"
	# In the latter case, the command output is piped into a bm.log file in the workspace dir
	build do |version, workspace|
  		puts "BOOM: #{version}"
		run "< build it >"
	end


***

