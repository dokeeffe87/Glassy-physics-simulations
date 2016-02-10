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
# Data Conversion to LAMMPS                                       #
# Created by: Dan on 12/02/2010                                   #
# University of Ottawa                                            #
###################################################################

##############
# Parameters #
##############

set n_monomers [expr $l_poly]

set n_polymers [expr $num_poly]

set num_particles [expr $n_monomers*$n_polymers]

set box_length [expr pow($num_particles/$density, 1.0/3.0)]

set box_l $box_length

set n_bonds [expr ($n_monomers - 1)*$n_polymers]

set n_part_types 1

set agetime [expr $age_step*$age_int_times]

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

#set int_steps 100

#set int_n_times 1500

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

set in [open "|gzip -cd checkpoint_aged_{100}_block.gz" "r"]
while { [blockfile $in read auto] != "eof" } {}
analyze set chains 0 $n_polymers $n_monomers
set pressure_const [analyze pressure total]
puts $pressure_const
puts [part 0 print id pos]
integrate 50
if {$vmd} {imd positions}

##################################################
# Trying to convert the data to a polyBlockWrite #
##################################################

puts "[galileiTransformParticles]"

polyBlockWrite "LAMMPS_Checkpoint_Quenched.gz"

#############################################################
#      Saving the appropriate file for LAMMPS               #
#############################################################

puts "Saving the data in LAMMPS friendly format"

# prepare observable output
set obs_file_LAMMPS_output [open "Espresso_to_LAMMPS_Aged$agetime" "w"]

# Header file
puts $obs_file_LAMMPS_output "LAMMPS data file from Espresso preparation \n"

###########################
# Put system information  #
###########################

# Number of atoms
puts $obs_file_LAMMPS_output "$num_particles atoms"
# Number of bonds
puts $obs_file_LAMMPS_output "$n_bonds bonds"

puts $obs_file_LAMMPS_output ""
# Atom types
puts $obs_file_LAMMPS_output "$n_part_types atom types"
# Bond types
puts $obs_file_LAMMPS_output "$n_part_types bond types"

puts $obs_file_LAMMPS_output ""
# Triclinic box
puts $obs_file_LAMMPS_output "0 0 0 xy xz yz"

puts $obs_file_LAMMPS_output ""
# Box dimensions
puts $obs_file_LAMMPS_output "0 $box_l xlo xhi"
puts $obs_file_LAMMPS_output "0 $box_l ylo yhi"
puts $obs_file_LAMMPS_output "0 $box_l zlo zhi"

puts $obs_file_LAMMPS_output ""
# Masses
puts $obs_file_LAMMPS_output "Masses\n"
for {set i 1} {$i <= $n_part_types} {incr i} {
        puts $obs_file_LAMMPS_output "$i 1"
}
# Continue from here later
puts $obs_file_LAMMPS_output ""
# Atoms info
puts $obs_file_LAMMPS_output "Atoms\n"
set j 0
for {set i 0} {$i < $num_particles} {incr i} {
        if {$i%$l_poly==0} {
                incr j
        }
        set p [part $i print pos type]
        set pf [part $i print folded_position]
        set x [lindex $p 0]
        set y [lindex $p 1]
        set z [lindex $p 2]
        set xf [lindex $pf 0]
        set yf [lindex $pf 1]
        set zf [lindex $pf 2]
        set type [expr [lindex $p 3]+1]
        
        if {$x>0} {
                set nx [expr int($x/$box_l)]
        } else {
                set nx [expr int($x/$box_l-1)]
        }
        if {$y>0} {
                set ny [expr int($y/$box_l)]
        } else {
                set ny [expr int($y/$box_l-1)]
        }
        if {$z>0} {
                set nz [expr int($z/$box_l)]
        } else {
                set nz [expr int($z/$box_l-1)]
        }
        
        puts $obs_file_LAMMPS_output "[expr $i+1] $j $type $xf $yf $zf $nx $ny $nz"
}

puts $obs_file_LAMMPS_output ""
# Velocities
puts $obs_file_LAMMPS_output "Velocities\n"
for {set i 0} {$i < $num_particles} {incr i} {
        set p [part $i print v]
        set vx [lindex $p 0]
        set vy [lindex $p 1]
        set vz [lindex $p 2]
        
        puts $obs_file_LAMMPS_output "[expr $i+1] $vx $vy $vz"
}

puts $obs_file_LAMMPS_output ""
# Bonds
puts $obs_file_LAMMPS_output "Bonds\n"
set j 1
for {set i 0} {$i < $num_particles} {incr i} {
        set p [part $i print bond]
        set bond [lindex [lindex [lindex $p 0] 0] 1]
        if {$i%$l_poly != 0} {
                puts $obs_file_LAMMPS_output "$j 1 [expr $bond+1] [expr $i+1]"
                incr j
        }
}

close $obs_file_LAMMPS_output

puts "Data conversion completed successfully"
exit