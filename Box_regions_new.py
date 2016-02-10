#!/usr/bin/env python

# Try to produce propensity plots of regions in the huge simulation!

# Import the relevant libraries

import getopt, sys, os

import numpy as np

import pylab as py

import matplotlib as plt

# Path for tools
pizza_tools = ['/Users/Dan/Documents/packages/pizza-8Dec09/src']
sys.path = sys.path + pizza_tools

# Source external functions
from dump import *

# Define a list for the shear values
shear = ['0','0.01','0.03','0.05','0.07','0.1','0.2','0.3']
direction = 'xy'

# We also need a list of the strain values used
strain_list = ['0','0.01','0.03','0.05','0.07','0.1','0.2','0.3']
strain_list = ['0']
strain_loop = len(strain_list)

# Set the number of particles
num_parts = 100352

# Define the simulation box boundaries for the undeformed case, we can use this and the shear values to determine the new box boundaries!
x_low = 298.543
y_low = 298.543
x_hi = 703.216
y_hi = 703.216 

# Define a list containing the number of timesteps in the simulation output
steps_list = np.array([])

for p in range(50000,660000,10000):
	convert = str(p)
	steps_list = np.append(steps_list,convert)

steps_loop = len(steps_list)

# Define the temperature
temp = '0.45'

for q in range(0,strain_loop):
	strain = strain_list[q]
	
	# Define an array to store the MSD values, initially 0
	MSD = np.zeros(num_parts,dtype=float)

	print len(MSD)
			
	# Read in the dump files
	d = dump('Shear_BLJ_glass_TEMP'+temp+'_STRAIN'+strain+'_DIRxy_EQUIL.dump')
	df = dump('Shear_BLJ_glass_TEMP'+temp+'_STRAIN'+strain+'_DIRxy.REMAPPED.dump')
			
	# Assign names to columns
	d.map(1,"id",2,"type",3,"xu",4,"yu",5,"zu",6,"vx",7,"vy",8,"vz",9,"ix",10,"iy",11,"iz",12,"x",13,"y",14,"z")
	df.map(1,"idf",2,"typef",3,"xuf",4,"yuf",5,"zuf",6,"vxf",7,"vyf",8,"vzf",9,"ixf",10,"iyf",11,"izf",12,"xf",13,"yf",14,"zf")
			
	# Now we need to compute the mean square displacement by finding the particle data at each snapshot!
	
			
	# Isolate the initial positions of all the particles to be used later!
	d.tselect.one(50000)
	d.sort()
	t = d.time()
	int_x,int_y = d.vecs(t[-1],"x","y")
		
	for g in range(0,steps_loop-1):
		step = int(steps_list[g])
		step2 = step + 10000
				
		# Select the first timestep
		d.tselect.one(step)
				
		# Sort the atoms by there id
		d.sort()
				
		# Timestep vector
		t = d.time()
				
		# Select the atoms in the desired time step
		#id,type,x1,y1 = d.vecs(t[-1],"id","type","x","y")
		id,type,x1,y1 = d.vecs(t[-1],"id","type","xu","yu")
			
		# Select the next timestep
		d.tselect.one(step2)
				
		# Sort the atoms by id
		d.sort()
				
		# Timestep vector
		t = d.time()
				
		# Select the atoms in the desired time step
		#id,type,x2,y2 = d.vecs(t[-1],"id","type","x","y")
		id,type,x2,y2 = d.vecs(t[-1],"id","type","xu","yu")
		
		#if step2 == 150000:
		
			#xf = x2
			#yf = y2
			#idf = id
			#typef = type
		
		# Use the final timestep to get the final positions of the particles, this way, we don't have any weird effects on the MSD values!!
		if step2 == 650000:
				
			# Select the next timestep (new dump file!!)
			df.tselect.one(step2)
				
			# Sort the atoms by id
			df.sort()
				
			# Timestep vector
			tf = df.time()
				
			# Select the atoms in the desired timestep
			idf,typef,xf,yf = df.vecs(tf[-1],"idf","typef","xf","yf")
				
				
		# compute the distance traveled by each particle 
				
		for h in range(0,num_parts):
			dist_x = x2[h] - x1[h]
			dist_y = y2[h] - y1[h]
			dr_2 = (dist_x**2) + (dist_y**2)
			MSD[h] = MSD[h] + dr_2
				
	# Now, average over the number of time intervals considered in order to get the mean square displacement of all the particles
	for w in range(0,num_parts):
		MSD[w] = MSD[w]/(steps_loop - 1)
		
	# Finally, determine the final position of all the particles as those of the particles in the remapped box. UNCOMMENT IF YOU NEED TO DO THIS:
	#df.tselect.one(450000)
	
	# Sort atoms by id
	#df.sort()
	
	# Timestep vector
	#tf = df.time()
	
	# Select the atoms in the desired timestep
	#idf,typef,xf,yf = df.vecs(tf[-1],"idf","typef","xf","yf")
		
	# Save the data to a file so that we can use it (for each strain, to compute the all coveted colour map that we want!)
	
	# For the mean square displacement values
	int_xt = np.transpose(int_x)
	int_yt = np.transpose(int_y)
	final_xt = np.transpose(xf)
	final_yt = np.transpose(yf)
	msdt = np.transpose(MSD)
	final_idt = np.transpose(idf)
	final_typet = np.transpose(typef)
	Colour_map_list = np.array([int_xt])
	Colour_map_list = np.append(Colour_map_list,[int_yt],axis=0)
	Colour_map_list = np.append(Colour_map_list,[final_xt],axis=0)
	Colour_map_list = np.append(Colour_map_list,[final_yt],axis=0)
	Colour_map_list = np.append(Colour_map_list,[msdt],axis=0)
	Colour_map_list = np.append(Colour_map_list,[final_idt],axis=0)
	Colour_map_list = np.append(Colour_map_list,[final_typet],axis=0)
	np.savetxt('Data_for_Colour_Map_SHEAR_REMAP_Corrected_FOLD_EQUIL'+strain+'_TEMP'+temp+'.dat',Colour_map_list.T)
	
	# Before shearing UNCOMMENT TO USE.
	#int_xt = np.transpose(int_x)
	#int_yt = np.transpose(int_y)
	#final_xt = np.transpose(xf)
	#final_yt = np.transpose(yf)
	#msdt = np.transpose(MSD)
	#final_idt = np.transpose(idf)
	#final_typet = np.transpose(typef)
	#Colour_map_list = np.array([int_xt])
	#Colour_map_list = np.append(Colour_map_list,[int_yt],axis=0)
	#Colour_map_list = np.append(Colour_map_list,[final_xt],axis=0)
	#Colour_map_list = np.append(Colour_map_list,[final_yt],axis=0)
	#Colour_map_list = np.append(Colour_map_list,[msdt],axis=0)
	#Colour_map_list = np.append(Colour_map_list,[final_idt],axis=0)
	#Colour_map_list = np.append(Colour_map_list,[final_typet],axis=0)
	#np.savetxt('Data_for_Colour_Map_SHEAR_REMAP_Corrected_FOLD_EQUIL_BEFORE_TEMP'+temp+'.dat',Colour_map_list.T)
			
# With this data, we should be able to produce the colour map we want!

print "AAARRRRR!!! Program be done!"

# End of program.
			
			
