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

set parameters {node l_poly num_poly temp gamma density glasstemp age_step age_int_times}
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

###################################################################
# Quenching a Polymer Melt                                        #
# Created by: Dan on 05/01/2010                                   #
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

set name "Quench"

set ident "_Length{$n_monomers}_Numberofpolymer{$n_polymers}_Gamma{$gamma}_Temp{$temp}_GlassTemp{$glasstemp}_Age_step{$age_step}_Quench"

#####################
# System parameters #
#####################

setmd box_l $box_length $box_length $box_length
setmd periodic 1 1 1 

setmd time_step 0.005

setmd skin 0.4

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


# Main integration parameters

set int_steps 100

set int_n_times 1500

#set int_steps 10

#set int_n_times 100

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


#########################
# prepare vmd conection #
#########################

if { $vmd } {
prepare_vmd_connection "$name$ident" 10 1
imd listen 40
}

if {$vmd} {imd positions}
setmd time 0.0

analyze set chains 0 $n_polymers $n_monomers
#set pressure [analyze pressure total]
#puts $pressure
#puts [part 0 print id pos]

###################
# Load Checkpoint #
###################

set in [open "|gzip -cd checkpoint_block.gz" "r"]
while { [blockfile $in read auto] != "eof" } {}
analyze set chains 0 $n_polymers $n_monomers
set pressure_const [analyze pressure total]
puts $pressure_const
puts [part 0 print id pos]
integrate 50
if {$vmd} {imd positions}

#################################################
# Analyze the average distance between monomers #
#################################################

# find the length of the chain
#set partpos ""
#for {set k 700} {$k < 799} {incr k} {
#lappend partpos [part $k print pos]
#puts $partpos
#}

#set lsum "0.00000"

#for {set k 0} {$k < [expr 98]} {incr k} {
#set part1 [lindex $partpos $k]
#set part2 [lindex $partpos [expr $k+1]]
#set dist [expr pow(pow([lindex $part1 0]-[lindex $part2 0],2)+pow([lindex $part1 1]-[lindex $part2 1],2)+pow([lindex $part1 2]-[lindex $part2 2],2),0.5)]
#set lsum [expr $lsum+$dist]
#}

#set average_distance [expr $lsum/$l_poly]
#puts $average_distance


########################
# Prepare output files #
########################
if {$observe} {
set name "Quench"
set ident "_Length{$n_monomers}_Numberofpolymer{$n_polymers}_Gamma{$gamma}_Temp{$temp}_GlassTemp{$glasstemp}_Age_Step{$age_step}_Age_int_times{$age_int_times}_Quench"
#set obs_quench_file [open "/Volumes/Second HD/GlassProject/DiffusionMelt/$name$ident.obs" "w"]
set obs_quench_file [open "$name$ident.obs" "w"]
puts $obs_quench_file "\# $name$ident: Observables for the quenched system"
puts $obs_quench_file "\# Time    RG_avg    RE_avg    E_TOT   E_KIN   Pressure   temperature"  
set name2 "Aged"
set ident2 "_Length{$n_monomers}_Numberofpolymer{$n_polymers}_Gamma{$gamma}_Temp{$temp}_GlassTemp{$glasstemp}_Age_Step{$age_step}_Age_int_times{$age_int_times}_AgedSystem"
#set obs_aged_file [open "/Volumes/Second HD/GlassProject/DiffusionMelt/$name2$ident2.obs" "w"]
set obs_aged_file [open "$name2$ident2.obs" "w"]
set $obs_aged_file "\# $name2$ident2: Observables for the aged system"
puts $obs_aged_file "\# Time    RG_avg    RE_avg    E_TOT   E_KIN   Pressure"
}

#####################################################
# Quench the system another way try maintaining NVT #
#####################################################

set step_temp $temp

for {set i 0} {$i < $int_n_times} {incr i} {

thermostat off

set time [setmd time]
flush stdout

integrate set nvt

thermostat langevin $step_temp $gamma
puts $step_temp

integrate $int_steps

set step_temp [expr $step_temp - 0.00066666666667]
#set step_temp [expr $step_temp - 0.01]
puts $step_temp
puts "thar be a space here!"

# Here we will decide which paramters we would like to output

set energy [analyze energy]
set pressure [analyze pressure total]
set RG [lindex [analyze rg] 0]
set RE [lindex [analyze re] 0]

if {$observe} {

puts $obs_quench_file [format "%.3e %.5e %.5e %.5e %.5e %.5e %.5e" $time $RG $RE [lindex [lindex $energy 0] 1] [lindex [lindex $energy 1] 1] $pressure $step_temp]
flush $obs_quench_file
}

# Here we will output a checkpoint to store the glassy state, do it say every 100 time steps

set p [expr $i*pow($int_n_times, -1)]
set mod [expr $i%100]
set per [expr $p*100]
set outmod [expr $i%10000]

if {$mod == 0} {
	puts "$per percent complete!"
  }

if {$observe} {  
if {$outmod == 0} {
	set out [open "|gzip -c - > checkpoint_Quenching_The_Melt_block.gz" "w"]
	blockfile $out write variable all
	blockfile $out write interactions
	blockfile $out write random
	blockfile $out write bitrandom
	blockfile $out write particles "id pos type q v f" all
	blockfile $out write bonds all
	blockfile $out write configs
	close $out
}
}

}

###################################################################
# Integrate the system at constant pressure for a while for aging #
###################################################################

set new_pressure [analyze pressure total]
puts $new_pressure
set simtime [list]

thermostat off

flush stdout

#Initialising the thermostat to a Isotropic NPT thermostat

set p_ext $new_pressure
set piston_mass 0.0001
set gamma_0 0.5
set gamma_v 0.001

integrate set npt_isotropic $p_ext $piston_mass 
thermostat set npt_isotropic $glasstemp $gamma_0 $gamma_v

for {set k 0} {$k < $age_int_times} {incr k} {

set time [setmd time]

integrate $age_step

lappend simtime $time
#puts $time
#puts $simtime 

set age_pressure [analyze pressure total]
puts $age_pressure
set age_energy [analyze energy]
set age_RG [lindex [analyze rg] 0]
set age_RE [lindex [analyze re] 0]

if {$observe} {

puts $obs_aged_file [format "%.3e %.5e %.5e %.5e %.5e %.5e" $time $age_RG $age_RE [lindex [lindex $age_energy 0] 1] [lindex [lindex $age_energy 1] 1] $age_pressure]
flush $obs_aged_file
}

analyze append 

}

# Write a check point of the aged glassy state

if {$observe} {
	set out [open "|gzip -c - > checkpoint_aged_{$age_step}_block.gz" "w"]
	blockfile $out write variable all
	blockfile $out write interactions
	blockfile $out write random
	blockfile $out write bitrandom
	blockfile $out write particles "id pos type q v f" all
	blockfile $out write bonds all
	#blockfile $out write configs
	close $out
}


set vanhove_file [open "AutocorrelationData.obs" "w"]
puts $vanhove_file "\# Autocorrelation data for means square displacement"
puts $vanhove_file "MSD   Time" 
for {set q 0} {$q < 999} {incr q} {
puts $vanhove_file [format "%.3e %.5e" [lindex [lindex [lindex [analyze vanhove 0 0 99 2] 0] 1] $q] [lindex $simtime $q]]
puts [lindex [lindex [lindex [analyze vanhove 0 0 99 2] 0] 1] $q]
puts [lindex $simtime $q]]
}
close $vanhove_file
puts [lindex [lindex [analyze vanhove 0 0 99 2] 0] 1]


#####################
# End of simulation #
#####################

set stoptime [clock seconds]
puts "\n Simulations terminated without error at [clock format $stoptime]"
set usedtime [expr $stoptime - $starttime]
puts "Total time used: [format "%02u:%02u:%02u" [expr $usedtime/(60*60)] [expr ($usedtime%(60*60))/60] [expr ($usedtime%60)]]."
exit

