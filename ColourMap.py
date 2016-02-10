#!/usr/bin/env python

# Try to make the colour map of the large simulation based on MSD values

# Import libraries

import getopt, os, sys

import numpy as np

import pylab as py

import matplotlib as plt

# Define the strain value, change this as necessary
strain_list = ['0','0.01','0.03','0.05','0.07','0.1','0.2','0.3']
strain = strain_list[1]

# Define the temperature used
temp = '0.45'

# Set the number of particles
num_parts = 100352

# Define the simulation box boundaries (this is the remapped box values)
x_low = 298.543
y_low = 298.543
x_hi = 703.216
y_hi = 703.216

int_x,int_y,final_x,final_y,msd,id,type = np.loadtxt('Data_for_Colour_Map_SHEAR_REMAP_Corrected_FOLD_EQUIL'+strain+'_TEMP'+temp+'.dat',unpack=True)

# Break the box up into bins and average the mean square displacements in the region:

# Define an array to store the mean square displacements of the regions
msd_region = np.zeros((100,100),dtype=float)
count = np.zeros((100,100),dtype=int)

# Divide the box up into 100 segments in both x and y:
epsilony = 4.04673
epsilonx = 4.04673


# Faster way
for i in range(num_parts):
	# Determine bin of x axis
	#binx = int((int_x[i]-x_low)/epsilonx)
	binx = int((final_x[i]-x_low)/epsilonx)

	# Same thing in y
	#biny = int((int_y[i]-y_low)/epsilony)
	biny = int((final_y[i]-y_low)/epsilony)

	
	#if binx >30 and binx < 50 and biny >30 and biny < 50:
	
	msd_region[binx,biny] += msd[i]
	count[binx,biny] += 1

# Get normalized averages
for i in range(100):
	for j in range(100):
		if count[i,j] > 0:
			msd_region[i,j] = msd_region[i,j]/count[i,j]
			
# Find the maximum and the minimum mean square displacements for the considered shear value:
maximum = np.max(msd_region)
minimum = np.min(msd_region)
for k in range(100):
	for l in range(100):
		msd_region[k,l] = ((msd_region[k,l] - minimum)/maximum)

np.savetxt('Region_MSD_UNFOLD_STRAIN_initial'+strain+'.dat',msd_region)
#np.savetxt('Region_MSD_UNFOLD_STRAIN_initial.dat',msd_region)


# The system should now be binned into a 100x100 box of equal length and the average mean square displacements of the regions should be computed!
# Make the colour map!! UNCOMMENT FOR THE TASK YOU ARE INTERESTED IN.

py.figure()
#py.imshow(msd_region[3:-3,3:-3],interpolation='bilinear',origin='lower',extent=(x_low,x_hi,y_low,y_hi))
py.imshow(msd_region.T,interpolation='bilinear',origin='lower',extent=(x_low,x_hi,y_low,y_hi))
py.title('Density Map of Normalized Particle Displacement For Shear'+' '+strain)
#py.title('Density Map of Normalized Particle Displacement For Shear_initial'+' '+strain)
#py.title('Density Map of Normalized Particle Displacement Before Shearing')
py.xlabel('x')
py.ylabel('y')
py.savefig('Colour_Map_Strain'+strain+'_temp'+temp+'_NormalizedMSD_EQUIL.pdf')
py.savefig('Colour_Map_Strain'+strain+'_temp'+temp+'_NormalizedMSD_EQUIL.png')
#py.savefig('Colour_Map_Strain'+strain+'_temp'+temp+'_NormalizedMSD_EQUIL_initialpos.pdf')
#py.savefig('Colour_Map_Strain'+strain+'_temp'+temp+'_NormalizedMSD_EQUIL_initialpos.png')
#py.savefig('Colour_Map_Strain_BEFORE_temp'+temp+'_NormalizedMSD_EQUIL.pdf')
#py.savefig('Colour_Map_Strain_BEFORE_temp'+temp+'_NormalizedMSD_EQUIL.png')
py.show()


		
		
		

	