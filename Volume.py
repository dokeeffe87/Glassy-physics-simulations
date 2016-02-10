#!/usr/bin/env python

# Read in data files in order to measure the mean squared displacement as a function of time for each temperature

# Import libraries

import getopt, sys, os

import numpy as np

import pylab as pl

import matplotlib as plt

# Path for tools

pizza_tools = ['/Users/Dan/Documents/packages/pizza-8Dec09/src']
sys.path = sys.path + pizza_tools

# Source external functions
from log import *

# Define a list of the possible temperature values

temp_list = ['0.2','0.3','0.4','0.41','0.42','0.43','0.44','0.45','0.46','0.47','0.48','0.49','0.5','0.6','0.7','0.8','0.9','1.0']
temp_list2 = [0.2,0.3,0.4,0.41,0.42,0.43,0.44,0.45,0.46,0.47,0.48,0.49,0.5,0.6,0.7,0.8,0.9,1.0]
lenT = len(temp_list)
volAvg = np.array([])


# Read in the log files using the pizza.py tools!

#for i in range(0,1):
for i in range(0,lenT):
	temp = temp_list[i]
	tmp = str(temp)
	l = log("log.BLJ.Glass.temp"+tmp+".checkbehaviour.RUNNING")

	time,temp,vol = l.get("Step","Temp","Volume")
	print vol
	# Now we need to average the volumes (they are actually areas!!) that were just extacted from the data files
	
	num = len(time)
	lenV = len(vol)
	AvgVol = 0
	
	for j in range(0,lenV):
		AvgVol = AvgVol + vol[j]
	
	TempVol = AvgVol/num
	volAvg = np.append(volAvg, TempVol)

# Plot the results to see how the volume changes with temperature!
data = np.array([temp_list2,volAvg])
np.savetxt('Data_area.dat',data.T)

pl.figure()
pl.plot(temp_list, volAvg, 'bo')
pl.show()
	



print "AAARR!  Program be done!"
	