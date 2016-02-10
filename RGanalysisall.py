#!/usr/bin/env python

# Import files containing the average radius of gyration data and average over them

# Import libraries

import sys, getopt, os

import numpy as np

import pylab as pl

import matplotlib.pyplot as plt

# Open the proper files and get the required data out

num = ['0','0.01','0.02','0.07','0.1','0.2']
nnum = len(num)

dir = ['xy','xz','yz']
ndir = len(dir)

while True:

	user_input = input('For RG^2 input 1, For RG input 2, For Semi-Log input 3:\n')
	if user_input == 1 or user_input == 2 or user_input == 3:
		break
	if user_input != 1 or user_input != 2 or user_input !=3:
		print "Choose either option 1, 2 or 3"
		

for t in range(nnum):
	q = num[t]
	
	sum = 0
	sum2 = 0
	
	for x in range(ndir):
		d = dir[x]

		count = list()

		for i in range(2,41):
			conv = str(i)
			count.append(conv)
	
		ncount = len(count)

		# Get the time


	
		fname = '/Volumes/SecondHD/Summer2010/PreparedSystems/shear1.t0.4.'+d+'.e'+q+'.rg'
	

		time,rg = np.loadtxt(fname,skiprows=2,unpack=True)
		sum2 = sum2 + rg
		sum = sum + np.sqrt(rg)

		for k in range(ncount):
			l = count[k]
			f = open('/Volumes/SecondHD/Summer2010/PreparedSystems/shear'+l+'.t0.4.'+d+'.e'+q+'.rg', 'r')
			time,rg2 = np.loadtxt(f,skiprows=2,unpack=True)
			sum2 = sum2 + rg2
			sum = sum + np.sqrt(rg2)
		
	rgavg = sum/(ndir*ncount)
	rgavg2 = sum2/(ndir*ncount)

	col = ['r-', 'b-', 'g-', 'y-', 'm-', 'c-']
	
	if user_input == 1:
		pl.figure(1)
		pl.plot(time, rgavg2, col[t])
		pl.xlabel('Time (LJ Units)')
		pl.ylabel('RG^2')
		pl.title('RG^2 as a Function of Time')
		pl.hold(True)
	
	if user_input == 2:
		pl.figure(1)
		pl.plot(time, rgavg, col[t])
		pl.xlabel('Time (LJ Units)')
		pl.ylabel('Average Radius of Gyration')
		pl.title('RG as a Function of Time')
		pl.hold(True)
	
	if user_input == 3:
		pl.figure(1)
		pl.plot(np.log(time), rgavg2, col[t])
		pl.xlabel('Time')
		pl.ylabel('RG^2')
		pl.title('RG^2 as a Function of Time (Semi-Log plot)')
		pl.hold(True)


if user_input == 1:
	pl.legend(('$\epsilon$ = 0','$\epsilon$ = 0.01','$\epsilon$ = 0.02','$\epsilon$ = 0.07','$\epsilon$ = 0.1','$\epsilon$ = 0.2'), 'upper right')	
	pl.savefig('RG_squared_500000_data.pdf')
	pl.savefig('RG_squared_500000_data.png')
	pl.show()

if user_input == 2:
	pl.legend(('$\epsilon$ = 0','$\epsilon$ = 0.01','$\epsilon$ = 0.02','$\epsilon$ = 0.07','$\epsilon$ = 0.1','$\epsilon$ = 0.2'), 'upper right')
	pl.savefig('RG_500000_data.pdf')
	pl.savefig('RG_500000_data.png')	
	pl.show()

if user_input == 3:
	pl.legend(('$\epsilon$ = 0','$\epsilon$ = 0.01','$\epsilon$ = 0.02','$\epsilon$ = 0.07','$\epsilon$ = 0.1','$\epsilon$ = 0.2'), 'upper right')
	pl.savefig('Semi-Log_RG_squared_500000_data.pdf')
	pl.savefig('Semi-Log_RG_squared_500000_data.png')
	pl.show()








