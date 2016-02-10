#!/bin/sh
# tricking... the line after these comments are interpreted as standard shell script \
exec $ESPRESSO_SOURCE/Espresso $0 $*
#
# ESPResSo simulation script with smart command line parser.
# Copyright (c) Kaigrass, 2007

# Problem description:
# This script can be used to simulate ...

#############################################################
# Smart command line parser
#############################################################
# This is the smart command line parser.
#
# It allows for easy specifications of parameters and options
# for the simulation script, without the need for manually
# parsing the command line. The parser checks for completeness
# of arguments but doesn't check the sanity of the values.
# 
# All parameters that you want to use in this script and that
# shall be read from the command line arguments given to the
# script have to be specified as a list named "parameters".
# 
# The parameters will have the name specified in this list
# (and thus can be referenced by $name) and will be initialised
# with the value given in the command line.  All parameters are
# considered required parameters and values have to be provided.
# Value assignment occurs by order in the parameter list.
#
# Note: The ESPResSo wrapper for the parallel version
# expects the first parameter (after the script name) to be
# the number of nodes(cpus) the script should be executed on.
# It is advisable that you follow this definition.
#
# Options can be specified in the list "options". Each option
# represents a flag that is 0 (false) if the option is not given
# and 1 (true) otherwise. On the command line, all options have
# to be preceded by "--". It is possible to obmit the end of an
# option as long as it remains unique.
#
# If an option demands for additional parameters, they can be
# specified along with the option in braces. Like regular parameters
# they will be defined as a variable of the same name with the
# values following the option on the command line. Any number of
# additonal parameters can be specified for each option.
#
# Options can be specified at any point in the argument list and
# in any order. To be compatible with the MPI-Wrapper, you should
# not start with an option.
#
# After specifying parameters and options no changes have to be
# made up to the "Start of program" mark (line 194).
# Enjoy.
#
# Example:
#
# set parameters {nodes npc chains density run}
# set options {debug vmd {randomseed seed} {integrator temp gamma}}
#
# This will parse 5 arguments from the command line and
# assigned to the variables named "nodes", "npc", "chains",
# "density", and "run".
# The command line can contain any of the following options:
# --debug, --vmd, --randomseed, or --integrator. The option
# --randomseed has to be followed by a value that is assigned to
# the variable "seed". Likewise, the option --integrator has
# two required arguments: "temp" and "gamma"
# 
# ./Espresso parser.tcl 2 --vmd --random 1234 2 3 4 5
#

#set parameters {node l_poly num_poly temp gamma density glasstemp age_step age_int_times}
set parameters {node}
set options {debug vmd {randomseed seed} observe}
#############################################################
# Auxillary functions
#############################################################
# debug display function (only works with debug flag)
proc debug { text } {
  global debug
  if { $debug } {
    puts $text
  }
}

# display usage info
proc usage_info { {msg} {excode -1} } {
  global scriptname parameters options
  puts $msg
  puts "Usage: $scriptname"
  puts "\tRequired parameters: $parameters"
  puts "\tOptions: $options"
  exit $excode
}


#############################################################
# Automated parsing 
#############################################################
set scriptname [file tail $argv0]; # getting the script name
set num_params [llength $parameters]; # number of required parameter
set num_options [llength $options]; # number of different options

# default options to 0
for { set i 0 } { $i < $num_options } { incr i } {
  for { set j 0 } { $j < [llength [lindex $options $i]] } { incr j } {
    set [lindex [lindex $options $i] $j] 0
  }
}

# parse command line
set num_params_set 0; # number of arguments already set
set currarg 0; # current argument to be passed
while {$currarg < $argc } {
  switch -glob -- [lindex $argv $currarg] {
    --* {; # set options (starting with --) by name
      set curropt [lindex $argv $currarg]
      set curropt [string trimleft $curropt -]
      set optpos [lsearch -glob $options "$curropt*"]
      if { $optpos < 0 } { usage_info "Option not recognized: --$curropt." }
      set curropt [lindex [lindex $options $optpos] 0]
      set $curropt 1; incr currarg;
      for { set i 1 } { $i < [llength [lindex $options $optpos]] } { incr i } { set [lindex [lindex $options $optpos] $i] [lindex $argv $currarg]; incr currarg }
    }
    default {; # set required parameters by order
      if { $num_params_set < $num_params } { set [lindex $parameters $num_params_set] [lindex $argv $currarg]; incr num_params_set; incr currarg }
    }
  }
}
if { $num_params_set < $num_params } { usage_info "Not enough arguments ($num_params_set < $num_params)." }
unset currarg
unset num_params_set


#############################################################
#  Feedback                                                 #
#############################################################
# start time
set starttime [clock seconds]
# check number of assigned processors
set rnodes [setmd n_nodes]

# feedback
puts "[code_info]"
puts ""
puts "$scriptname"
puts "Started at [clock format $starttime] on $rnodes cpu(s)."
puts "Parameters:"
for { set i 0 } { $i < $num_params } { incr i } { puts "\t[lindex $parameters $i] = [set [lindex $parameters $i]]" }
puts "Options given:"
for { set i 0 } { $i < $num_options } { incr i } {
  if { [set [lindex [lindex $options $i] 0]] } {
    puts "\t[lindex [lindex $options $i] 0]"
    for { set j 1 } { $j < [llength [lindex $options $i]] } { incr j } {
      puts "\t\t[lindex [lindex $options $i] $j] = [set [lindex [lindex $options $i] $j]]"
    }
  }
}


#############################################
# Initialize random number generator
#############################################
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!!!!!!IMPORTANT!!!!!!!!!!!!!!!!!!!!
# otherwise Espresso always uses the same random numbers!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# check if randomseed and seed are available
if { [info exists randomseed] && [info exists seed] } {
  # if randomseed is not given get a random one from cpu time
  if { !($randomseed) } {
    set seed [expr abs([clock clicks]%100000)]
  }
  # use list to distribute random seeds to more
  # than one computing node
  for { set i 0 } { $i < $rnodes } { incr i } {
      lappend randomnums [expr $seed+$i*4543]
  }
  eval t_random seed $randomnums
  unset randomnums
}
puts "\nInitial random number generator state = [t_random seed]"

##########################################
# Extracting Data from LAMMPS Simulation #
##########################################

#for #{set q 0} #{$q < 10} #{incr q} #{

#set count [expr $q/100.00]
#set strain $count
#puts $strain

#set strainlist {0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1}
#set strain [lindex $strainlist $q]

set strain 0.5

set tcl_precision 8
set listofdata [list]
set calclist [list]
set alldatalist [list]
set slowPartlist [list]
set fastPartlist [list]
set distancelistslow [list]
set distancelistfast [list]
set sorteddistancelistslow [list]
set sorteddistancelistfast [list]
set testall [list]

set obs_LAMMPS_data [open "AGING.AGE100000.TEMP0.2.DIRxy.STRAIN$strain.DUMP" "r"]
fconfigure $obs_LAMMPS_data -buffering line
gets $obs_LAMMPS_data data
while {$data != ""} {
	#puts $data
	lappend listofdata $data
	gets $obs_LAMMPS_data data
	}
close $obs_LAMMPS_data

#puts $testdata
for {set i 9} {$i < 80009} {incr i} {
#puts [lindex $listofdata $i]
set velx [lindex [lindex $listofdata $i] 4]
set vely [lindex [lindex $listofdata $i] 5]
set velz [lindex [lindex $listofdata $i] 6]
set vel [expr pow(($velx*$velx) + ($vely*$vely) + ($velz*$velz), 0.5)]
set calclist [lindex $listofdata $i]
lappend calclist $vel
lappend alldatalist $calclist
}

set sortedlist [lsort -real -index 7 $alldatalist]
#puts $sortedlist

for {set j 0} {$j < 4000} {incr j} {
lappend slowPartlist [lindex $sortedlist $j]
}

for {set k 76000} {$k < 80000} {incr k} {
lappend fastPartlist [lindex $sortedlist $k]
}

#puts $fastPartlist
#puts [llength $fastPartlist]

#for {set q 0} {$q < 4000} {incr q} {
	#set px1 [lindex [lindex $slowPartlist $q] 1]
	#set py1 [lindex [lindex $slowPartlist $q] 2]
	#set pz1 [lindex [lindex $slowPartlist $q] 3]
	
	#for {set p $q} {$p < 4000} {incr p} {
		#set px2 [lindex [lindex $slowPartlist $p] 1]
		#set py2 [lindex [lindex $slowPartlist $p] 2]
		#set pz2 [lindex [lindex $slowPartlist $p] 3]
		
		#set dist [expr pow(($px2 - $px1)*($px2 - $px1) + ($py2 - $py1)*($py2 - $py1) + ($pz2 - $pz1)*($pz2 - $pz1), 0.5)]
		#lappend distanceslistslow $dist
		#puts $dist
	#}
#}

for {set q 0} {$q < 4000} {incr q} {
	set px1 [lindex [lindex $fastPartlist $q] 1]
	set py1 [lindex [lindex $fastPartlist $q] 2]
	set pz1 [lindex [lindex $fastPartlist $q] 3]
	
	for {set p $q} {$p < 4000} {incr p} {
		set px2 [lindex [lindex $fastPartlist $p] 1]
		set py2 [lindex [lindex $fastPartlist $p] 2]
		set pz2 [lindex [lindex $fastPartlist $p] 3]
		
		set dist [expr pow(($px2 - $px1)*($px2 - $px1) + ($py2 - $py1)*($py2 - $py1) + ($pz2 - $pz1)*($pz2 - $pz1), 0.5)]
		lappend distanceslistfast $dist
		#puts $dist
	}
}

#set sorteddistlistslow [lsort -real -index 0 $distanceslistslow]
set sorteddistlistfast [lsort -real -index 0 $distanceslistfast]
#puts $sorteddistlist

#set numslow [llength $sorteddistlistslow]
set numfast [llength $sorteddistlistfast]
#puts $num

set obs_fastpart_file [open "Fixed_List_of_fast_particle_distances_Age{100000}_Run{1000000}_Strain{$strain}.obs" "w"]
#set obs_slowpart_file [open "Fixed_List_of_slow_particle_distances_Age{100000}_Run{1000000}_Strain{$strain}.obs" "w"]

for {set l 0} {$l < $numfast} {incr l} {
set valuefast [lindex $sorteddistlistfast $l]
puts $obs_fastpart_file $valuefast
}

#for {set q 0} {$q < $numslow} {incr q} {
#set valueslow [lindex $sorteddistlistslow $q]
#puts $obs_slowpart_file $valueslow
#}

flush $obs_fastpart_file
#flush $obs_slowpart_file
puts "File created successfully!"

#}

exit