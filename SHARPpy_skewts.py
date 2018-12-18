#!/usr/bin/env python

"""

 load python and ncar_pylib before running this
> module load python
> ncar_pylib

"""

import glob,sys,os,argparse

# Call this before pyplot
# avoids X11 window display error as mpasrt
# says we won't be using X11 (i.e. use a non-interactive backend instead)
#import matplotlib
#matplotlib.use('Agg')
import myskewt # Put after matplotlib.use('Agg') or else you get a display/backend/TclError as user mpasrt.

import matplotlib.pyplot as plt
import datetime
from subprocess import call # to use "rsync"
import pdb

from metpy.plots import SkewT, Hodograph

import sharppy
import sharppy.sharptab.profile as profile
import sharppy.sharptab.interp as interp
import sharppy.sharptab.winds as winds
import sharppy.sharptab.utils as utils
import sharppy.sharptab.params as params
import sharppy.sharptab.thermo as thermo
import numpy as np
from StringIO import StringIO

parser = argparse.ArgumentParser(description='Plot skew-Ts')
parser.add_argument('init_time', type=str, help='yyyymmddhh')
parser.add_argument('-w','--workdir', type=str, help="working directory under /glade/scratch/mpasrt/. Ususally a name for MPAS mesh (e.g. 'conv', 'us', 'wp', 'ep', 'al')")
parser.add_argument('-i','--interval', type=int, help='plot interval in hours', default=3)
parser.add_argument('-p','--project', type=str, help='project', default='hur15us')
parser.add_argument('-v','--verbose', action="store_true", help='print more output.')
parser.add_argument('-d','--debug', action="store_true", help='debug mode.')
parser.add_argument('-f','--force_new', action="store_true", help='overwrite existing plots')
parser.add_argument('-n','--nplots', type=int, default=-1, help='plot first "n" plots. useful for debugging')
args = parser.parse_args()

debug = args.debug
force_new = args.force_new
nplots = args.nplots
project = args.project

if debug:
    print args
    pdb.set_trace()
odir = "/glade/scratch/mpasrt/%s/%s/plots"%(args.workdir,args.init_time)
if not os.path.exists(odir):
    os.makedirs(odir)
if args.verbose:
    print "change dir to", odir
    os.chdir(odir)
if not os.path.exists(args.init_time):
    os.makedirs(args.init_time)
# plot every *.snd file
sfiles = glob.glob("../*.snd")
sfiles.extend(glob.glob("../soundings/*.snd"))
#print sfiles
# cut down number of plots for debugging
sfiles.sort()
if nplots > -1:
    sfiles = sfiles[0:nplots]

def parseGEMPAK(sfile):
    ## read in the file
    data = np.array([l.strip() for l in sfile.split('\n')])
    ## Grab 3rd, 6th, and 9th words
    stidline = [i for i in data if "STID =" in i]
    stid, stnm, time = stidline[0].split()[2:9:3]
    slatline = [i for i in data if "SLAT =" in i]
    slat, slon, selv = slatline[0].split()[2:9:3]
    ## necessary index points
    start_idx = np.where(data == "PRES      HGHT     TMPC     DWPC     DRCT     SPED")[0][0] + 1
    finish_idx = len(data)
    ## put it all together for StringIO
    full_data = '\n'.join(data[start_idx : finish_idx][:])
    sound_data = StringIO( full_data )
    ## read the data into arrays
    p, h, T, Td, wdir, wspd = np.genfromtxt( sound_data, unpack=True)
    wdir[wdir == 360] = 0. # Some wind directions are 360. Like in /glade/work/ahijevyc/GFS/Joaquin/g132325165.frd
    return p, h, T, Td, wdir, utils.MS2KTS(wspd), float(slat), float(slon)

model_str = {"hwt2017":"MPAS-US 15-3km","us":"MPAS-US 60-15km","wp":"MPAS-WP 60-15km","al":"MPAS-AL 60-15km",
		"ep":"MPAS-EP 60-15km","uni":"MPAS 15km",
		"mpas":"MPAS 15km","mpas_ep":"MPAS-EP 60-15km","spring_exp":"MPAS","GFS":"GFS",
		"mpas15_3":"MPAS 15-3km","mpas50_3":"MPAS 50-3km","hwt":"MPAS HWT"}

no_ignore_station = ["S07W112","N15E121","N18E121","N20W155","N22W159","N24E124","N35E125","N35E127","N36E129","N37E127","N38E125","N40E140","N40W105"]

def get_title(sfile):
    title = sfile
    fname = os.path.basename(sfile)
    if '.snd' in fname:
        words = os.path.realpath(sfile).split('/')
        # Find 1st word in the absolute path that is yyyymmddhh format. Assume it is the initialization time.
        for i,word in enumerate(words):
            try:
                datetime.datetime.strptime(word, '%Y%m%d%H')
            except ValueError:
                continue
            break
        init_time = words[i]
        model = words[i-1]
        parts = fname.split('.')
        station = parts[0]
        valid_time = parts[1]
        fhr = datetime.datetime.strptime(valid_time, "%Y%m%d%H%M") - datetime.datetime.strptime(init_time,"%Y%m%d%H")
        fhr = fhr.total_seconds()/3600.
	if model not in model_str:
		print model, "is not in model_str. Can't get title"
		sys.exit(2)
        title = model_str[model]+'  %dh fcst' % fhr + '  Station: '+station+'\nInit: '+init_time+'  Valid: '+valid_time+' UTC'
    return title, station, init_time, valid_time, fhr
    
# Create a new figure. The dimensions here give a good aspect ratio
# Alter their positions within the loop using object methods like set_data(), set_text, set_position(), etc.

fig,ax = plt.subplots(figsize=(7.25,5.4))
plt.tight_layout(rect=(0.04,0.02,0.79,.96))
# Why do I get 0-1.0 ticks and labels? Erase them.
ax.get_xaxis().set_visible(False) # put after plt.tight_layout or axis labels will be cut off
ax.get_yaxis().set_visible(False)



for sfile in sfiles:


    skew = SkewT(fig, rotation=30)
    skew.ax.set_ylabel('Pressure (hPa)')
    skew.ax.set_xlabel('Temperature (C)')
    # example of a slanted line at constant temperature 
    l = skew.ax.axvline(-20, color='b', linestyle='dashed', alpha=0.5, linewidth=1)
    l = skew.ax.axvline(0, color='b', linestyle='dashed', alpha=0.5, linewidth=1)
    print "reading", sfile
    title, station, init_time, valid_time, fhr = get_title(sfile)
    if fhr % args.interval != 0:
        print "fhr not multiple of", args.interval, "skipping", sfile
        continue
    if len(station) > 3 and station not in no_ignore_station:
        print "skipping", sfile
        continue
    skew.ax.set_title(title, horizontalalignment="left", x=0, fontsize=12) 
    # Avoid './' on the beginning for rsync command to not produce "skipping directory ." message.
    ofile = init_time+'/'+project+'.skewt.'+station+'.hr'+'%03d'%fhr+'.png'
    if not force_new and os.path.isfile(ofile): continue
    data = open(sfile).read()
    pres, hght, tmpc, dwpc, wdir, wspd, latitude, longitude = parseGEMPAK(data)

    if wdir.size == 0:
        print "no good data lines. empty profile"
        continue

    prof = profile.create_profile(profile='default', pres=pres, hght=hght, tmpc=tmpc, 
                                    dwpc=dwpc, wspd=wspd, wdir=wdir, latitude=latitude, longitude=longitude, missing=-999., strictQC=True)

    #### Adding a Parcel Trace
    sfcpcl = params.parcelx( prof, flag=1 ) # Surface Parcel
    #fcstpcl = params.parcelx( prof, flag=2 ) # Forecast Parcel
    mupcl = params.parcelx( prof, flag=3 ) # Most-Unstable Parcel
    mlpcl = params.parcelx( prof, flag=4 ) # 100 mb Mean Layer Parcel
    # Set the parcel trace to be plotted as the Most-Unstable parcel.
    pcl = mupcl

    # Temperature, dewpoint, virtual temperature, wetbulb, parcel profiles
    temperature_trace, = skew.plot(prof.pres, prof.tmpc, 'r', linewidth=2) # temperature profile 
    # annotate temperature in F at bottom of T profile
    temperatureF = skew.ax.text(prof.tmpc[0], prof.pres[0]+10, utils.INT2STR(thermo.ctof(prof.tmpc[0])), 
            verticalalignment='top', horizontalalignment='center', size=7, color=temperature_trace.get_color())
    skew.plot(prof.pres, prof.vtmp, 'r', linewidth=0.5)                    # Virtual temperature profile
    skew.plot(prof.pres, prof.wetbulb, 'c-')                               # wetbulb profile
    dwpt_trace, = skew.plot(prof.pres, prof.dwpc, 'g', linewidth=2)        # dewpoint profile
    # annotate dewpoint in F at bottom of dewpoint profile
    dewpointF = skew.ax.text(prof.dwpc[0], prof.pres[0]+10, utils.INT2STR(thermo.ctof(prof.dwpc[0])), 
            verticalalignment='top', horizontalalignment='center', size=7, color=dwpt_trace.get_color())
    skew.plot(pcl.ptrace, pcl.ttrace, 'brown', linestyle="dashed" )        # parcel temperature trace 
    skew.ax.set_ylim(1050,100)
    skew.ax.set_xlim(-50,45)


    # Plot the effective inflow layer using purple horizontal lines
    eff_inflow = params.effective_inflow_layer(prof)
    inflow_bot = skew.ax.axhline(eff_inflow[0], color='purple',xmin=0.38, xmax=0.45)
    inflow_top = skew.ax.axhline(eff_inflow[1], color='purple',xmin=0.38, xmax=0.45)
    srwind = params.bunkers_storm_motion(prof)
    # annotate effective inflow layer SRH 
    if eff_inflow[0]:
        ebot_hght = interp.to_agl(prof, interp.hght(prof, eff_inflow[0]))
        etop_hght = interp.to_agl(prof, interp.hght(prof, eff_inflow[1]))
        effective_srh = winds.helicity(prof, ebot_hght, etop_hght, stu = srwind[0], stv = srwind[1])
        # Set position of label
        # x position is mean of horizontal line bounds
        # For some reason this makes a big white space on the left side and for all subsequent plots.
        inflow_SRH = skew.ax.text(
                np.mean(inflow_top.get_xdata()), eff_inflow[1],
                '%.0f' % effective_srh[0] + ' ' + '$\mathregular{m^{2}s^{-2}}$',
                verticalalignment='bottom', horizontalalignment='center', size=6, transform=inflow_bot.get_transform(), color=inflow_top.get_color()
                )

    # draw indices text string to the right of plot.
    indices_text = plt.text(1.08, 1.0, myskewt.indices(prof), verticalalignment='top', size=5.6, transform=plt.gca().transAxes)

    # globe with dot
    mapax = myskewt.add_globe(longitude, latitude)

    # Update the hodograph on the Skew-T.
    # Draw the hodograph on the Skew-T.
    hodo_ax = myskewt.draw_hodo()
    hodo, AGL = myskewt.add_hodo(hodo_ax, prof)

    # Plot Bunker's Storm motion left mover as a blue dot
    bunkerL, = hodo_ax.plot([], [], color='b', alpha=0.7, linestyle="None", marker="o", markersize=5, mew=0, label="left mover")
    # Plot Bunker's Storm motion right mover as a red dot
    # The comma after bunkerR de-lists it.
    bunkerR, = hodo_ax.plot([], [], color='r', alpha=0.7, linestyle="None", marker="o", markersize=5, mew=0, label="right mover")
    # Explanation for red and blue dots. Put only 1 point in the legend entry.
    bunkerleg = hodo_ax.legend(handles=[bunkerL,bunkerR], fontsize=5, frameon=False, numpoints=1)

    # show Bunker left/right movers if 0-6km shear magnitude >= 20kts
    p6km = interp.pres(prof, interp.to_msl(prof, 6000.))
    sfc_6km_shear = winds.wind_shear(prof, pbot=prof.pres[prof.sfc], ptop=p6km)
    if utils.comp2vec(sfc_6km_shear[0], sfc_6km_shear[1])[1] >= 20.:
        bunkerR.set_visible(True)
        bunkerL.set_visible(True)
        bunkerleg.set_visible(True)
        bunkerR.set_data(srwind[0], srwind[1]) # Update Bunker's Storm motion right mover
        bunkerL.set_data(srwind[2], srwind[3]) # Update Bunker's Storm motion left mover
    else:
        bunkerR.set_visible(False)
        bunkerL.set_visible(False)
        bunkerleg.set_visible(False)

    # Recreate stack of wind barbs
    s = []
    bot=2000.
    # Space out wind barbs evenly on log axis.
    for ind, i in enumerate(prof.pres):
        if i < 100: break
        if np.log(bot/i) > 0.04:
            s.append(ind)
            bot = i
    b = skew.plot_barbs(prof.pres[s], prof.u[s], prof.v[s], linewidth=0.4, length=6)
    # 'knots' label under wind barb stack
    kts = ax.text(1.0, 0, 'knots', clip_on=False, ha='center',va='bottom',size=7,zorder=2)

    # Tried drawing adiabats and mixing lines right after creating SkewT object but got errors. 
    draw_adiabats  = skew.plot_dry_adiabats(color='r', alpha=0.2, linestyle="solid")
    moist_adiabats = skew.plot_moist_adiabats(linewidth=0.5, color='black', alpha=0.2)
    mixing_lines   = skew.plot_mixing_lines(color='g', alpha=0.35, linestyle="dotted")


    string = "created "+str(datetime.datetime.now(tz=None)).split('.')[0]
    plt.annotate(s=string, xy=(10,2), xycoords='figure pixels', fontsize=5)
        
    res = plt.savefig(ofile,dpi=125)
    skew.ax.clear()
    ax.clear()
    if args.verbose:
        print 'created', os.path.realpath(ofile)
    mapax.clear()
    hodo_ax.clear()

    # Copy to web server
    if '.snd' in sfile: 
        cmd = "rsync -R "+ofile+" ahijevyc@nova.mmm.ucar.edu:/web/htdocs/projects/mpas/plots"
        print(cmd)
        call(cmd.split()) 

plt.close('all')

