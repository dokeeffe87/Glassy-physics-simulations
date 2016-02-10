#!/usr/bin/env python

# Import libraries

import getopt, sys, os

import numpy as np

import pylab as pl

import matplotlib as plt

# Generate a list to store the timestep values from 0 to 50000 by 100

time_list = np.array([])

for k in range(0,50001,100):
	time_list = np.append(time_list, k)

#print time_list	

# Create a list of temperatures

temp = ['0.2','0.3','0.4','0.45','0.5','0.6','0.7','0.8','0.9','1.0']
lentemp = len(temp)

# Create a list of plotting styles

styles = ['b-','g-','r-','c-','m-','y-','k-','w-','b--','g--']

for k in range(0,lentemp):
	t = temp[k]

	f = open('MSD.temp'+t+'.dat','r')

	# Find the beginning of the data

	f.readline()
	f.readline()
	f.readline()

	# Initialize an array to contain the MSD data

	msd_list = np.array([])

	while True:

		for i in range(0,4):
			testline = f.readline()
	
		if len(testline) == 0:
			break
	
		if len(testline) != 0:
			store = f.readline().rsplit()
			msd = float(store[1])
			msd_list = np.append(msd_list, msd)

	#print msd_list
	sys.stdout.flush()
	f.close()	

	# Plot the results

	pl.figure(1)
	pl.plot(time_list, msd_list, styles[k])
	pl.title('Mean Squared Displacement for Various Temperatures')
	pl.xlabel('Time Steps (in LJ Units)')
	pl.ylabel('Mean Squared Displacement')
	pl.hold(True)
	

pl.legend(('T = 0.2','T = 0.3','T = 0.4','T = 0.45','T = 0.5','T = 0.6','T = 0.7','T = 0.8', 'T = 0.9','T = 1.0'),'lower right')
pl.savefig('Mean_Squared_Displacement_Temps.pdf')
pl.savefig('Mean_Squared_Displacement_Temps.png')
pl.show()		
	
print "AAARR!  Program be done!"
	
	