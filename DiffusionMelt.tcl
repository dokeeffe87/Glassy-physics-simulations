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

set parameters {node l_poly num_poly temp gamma density}
set options {debug vmd {randomseed seed}}
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

###################################################################
# Polymer Melt System                                             #
# Created by: Dan on 16/10/2009                                   #
# University of Ottawa                                            #
###################################################################

##############
# Parameters #
##############

set n_monomers [expr $l_poly]

set n_polymers [expr $num_poly]

set num_particles [expr $n_monomers*$n_polymers]

set box_length [expr pow($num_particles/$density, 1.0/3.0)]

puts "A simulation of a system of $n_polymers polymers with $n_monomers monomers per chain"

puts "Simulation box length $box_length"

#########################
# System Identification #
#########################

set name "PolymerDiffusionMelt_system_New"

set ident "Length{$n_monomers}_Numberofpolymer{$n_polymers}_Gamma{$gamma}_Temp{$temp}_polymerDiffusionMelt"

#####################
# System parameters #
#####################

setmd box_l $box_length $box_length $box_length
setmd periodic 1 1 1 

setmd time_step 0.01

setmd skin 0.4

integrate set nvt

thermostat langevin $temp $gamma

##########################
# Interaction parameters #
##########################

#inter 0 fene 30.0 7.0
inter 0 fene 30.0 1.5

#inter 0 0 lennard-jones 1.0 1.0 1.12246 0.25 0
inter 0 0 lennard-jones 1.0 1.0 2.5 0.25 0

set bond_length 1.0

##########################
# Integration Parameters #
##########################

# Warm up parameters

set warm_steps 200

set warm_n_times 200

set min_dist 0.8

# Main integration parameters

set int_steps 100

set int_n_times 100000
# set int_n_times 10

###########################
# More general parameters #
###########################

set tcl_precision 8

################
# System Setup #
################

set initialpos_list [list]

set initialpos [expr $box_length/2.0]

polymer $n_polymers $n_monomers $bond_length pos $initialpos $initialpos $initialpos mode RW type 0 0 FENE 0

# Compute the temperature if you want

if { [regexp "ROTATION" [code_info]]} {
set deg_free 6
} else { set deg_free 3 }

set act_min_dist [analyze mindist] 

#########################
# prepare vmd conection #
#########################

if { $vmd } {
prepare_vmd_connection "$name$ident" 10 1
imd listen 40
}


#######################
# Wram up integration #
#######################

puts "\n Warm up integration proceeding"

puts "At maximum $warm_n_times times $warm_steps"

puts "Stop if minimal distance is larger than $min_dist"

if {$vmd} {imd positions}


set cap 20
inter ljforcecap $cap
set i 0
while {$i < $warm_n_times && $act_min_dist < $min_dist} {
	set time [format "%8f" [setmd time]]
	
#puts [analyze energy]
integrate $warm_steps

set act_min_dist [analyze mindist]
puts $act_min_dist
#if {$vmd} {imd positions}

set cap [expr $cap + 10]
puts $cap
inter ljforcecap $cap
incr i
}

puts "\n Warm up completed, minimum distance [analyze mindist]"
inter ljforcecap 0
setmd time 0.0

# Calculate the temperature of the system if you want to know it
set tempinstant [expr [analyze energy kinetic]/(($deg_free/2.0)*$n_monomers)]

analyze set chains 0 $n_polymers $n_monomers

if {$vmd} {imd positions}

#######################
# Prepare output files#
#######################

set name "PolymerDiffusionMelt_system_New"
set ident "_Length{$n_monomers}_Numberofpolymer{$n_polymers}_Gamma{$gamma}_Temp{$temp}_polymerDiffusionMelt"
set obs_polymermelt_file [open "$name$ident.obs" "w"]
puts $obs_polymermelt_file "\# $name$ident: Observables for the polymer melt"
puts $obs_polymermelt_file "\# Time     RG_avg      RE_avg     E_TOT      E_KIN    Pressure"

#################################################################
# Main Integration at high temperature to create a polymer melt #
#################################################################

set flag 0

analyze g123 -init

set RGint [lindex [analyze rg] 0]
#set RGint2 [expr $RGint*$RGint]

while {$flag < 1} {

for {set i 0} {$i <= $int_n_times } {incr i} {

set time [setmd time]
flush stdout

integrate $int_steps

set energy [analyze energy]
set pressure [analyze pressure total]
set diffusion [lindex [lindex [analyze g123] 0] 2]
set RG [lindex [analyze rg] 0]
set RE [lindex [analyze re] 0]
puts $obs_polymermelt_file [format "%.3e %.5e %.5e %.5e %.5e %.5e" $time $RG $RE [lindex [lindex $energy 0] 1] [lindex [lindex $energy 1] 1] $pressure]

flush $obs_polymermelt_file

#puts $pressure
#puts $equilibpara
puts "\n"
puts $RGint
#puts $RGint2
puts $RG
puts [analyze g123]
puts $diffusion
puts "\n"

if {$vmd} {imd positions}

set p [expr $i*pow($int_n_times, -1)]
set mod [expr $i%100]
set per [expr $p*100]
set outmod [expr $i%10000]

if {$mod == 0} {
	puts "$per percent complete!"
  }
  
if {$outmod == 0} {
	set out [open "|gzip -c - > checkpoint_new_block.gz" "w"]
	blockfile $out write variable all
	blockfile $out write interactions
	blockfile $out write random
	blockfile $out write bitrandom
	blockfile $out write particles "id pos type q v f" all
	blockfile $out write bonds all
	blockfile $out write configs
	close $out
}
   
 
if {$diffusion > [expr 20*$RGint]} {
	puts "System equilibriated!"
	set out [open "|gzip -c - > checkpoint_new_block.gz" "w"]
	blockfile $out write variable all
	blockfile $out write interactions
	blockfile $out write random
	blockfile $out write bitrandom
	blockfile $out write particles "id pos type q v f" all
	blockfile $out write bonds all
	blockfile $out write configs
	close $out
	set flag 1
	set i [expr $int_n_times + 1]
	}

}
}


##################
# End of program #
##################

set stoptime [clock seconds]
puts "\n Simulations terminated without error at [clock format $stoptime]"
set usedtime [expr $stoptime - $starttime]
puts "Total time used: [format "%02u:%02u:%02u" [expr $usedtime/(60*60)] [expr ($usedtime%(60*60))/60] [expr ($usedtime%60)]]."
exit

 













