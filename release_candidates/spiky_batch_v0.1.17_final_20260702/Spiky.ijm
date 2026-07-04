/*//////////////////////////////////////////////////////////////////////
// Spiky - peak Analysis V0.53
// Author: Côme PASQUALIN, François GANNIER
//
// Signalisation et Transport Ionique (STIM)
// CNRS ERL 7368, Groupe PCCV - Université de Tours
//
// Report bugs to authors
// gannier@univ-tours.fr
// come.pasqualin@univ-tours.fr
//
//  This file is part of Spiky.
//  Copyright 2016-2020 Côme PASQUALIN, François GANNIER	
//
//  Spiky is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Spiky is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Spiky.  If not, see <https://www.gnu.org/licenses/>.
////////////////////////////////////////////////////////////////// */

 	/* TIPS
	// openning AVI
		// if 8-bits check "convert to grayscale"
		// if speed of analysis is a priority uncheck "Use virtual stack"
		// if speed of openning is a priority or file is big check "Use virtual stack"
	*/	
	/*
	Si probleme avec focus log window
	remplacer selectImage par
		eval("script","IJ.selectWindow("+plotid+")"); 
	*/
	/*	Labels :start & end with " "
		Plot.setXYLabels(" time ["+ Tunits+"] ", " Mean [UA] ");
	*/

var Debug = call("ij.Prefs.get", "SPIKY.Debug",0);
var sVer = "Spiky v0.53";
var sCop = "Copyright 2015-2022 F.GANNIER - C.PASQUALIN";
var spikyBatchDirectPeakAnalysisOrientationSupport = "SPIKY.Batch.DirectPeakAnalysisOrientationSupport=v0.1.14";
var spikyBatchDirectMode = false;

//default axis name
var strVaxis = " Sarcomere length ";
var strVunit = fromCharCode(0x00B5)+"m";
var strHaxis = " Time ";
var strHunit = "s";

// parameter_map values
var analParam;
var valMoy = newArray(6);

//Calibration tools
var IJlocation = getDirectory("imagej") + "Calib" + File.separator;
var NumberOfProfiles = 0;

//Common_values
var largeur; var hauteur; var channels; var slices; var frames;
var channel, slice, frame;
var FI, fps;var pixelW; var pixelH; var pixelD; var unit; var Tunits;
var srcName; var nom_ori; var Nbits;
var Tprop = 0; // en second
var sensAna, pos, Ztab;
var BM=0;
var ampDiff=0;
var interpolate = true;

// Dependencies
var isHRtime = call("ij.Prefs.get", "PCCV.HRtime",0);
var isKD = call("ij.Prefs.get", "PCCV.KD",0);
var isSGolay = call("ij.Prefs.get", "PCCV.Golay",0);
var dep = testDependencies(call("ij.Prefs.get", "SPIKY.first",true));

spikyBatchDirectArg = getArgument();
if (startsWith(spikyBatchDirectArg, "SPIKY.Batch.PeakAnalysisOrientation=")) {
	spikyBatchDirectMode = true;
	spikyBatchDirectOrientation = getSpikyBatchArgumentValue(spikyBatchDirectArg, "SPIKY.Batch.PeakAnalysisOrientation");
	spikyBatchDirectWindow = getSpikyBatchArgumentValue(spikyBatchDirectArg, "SPIKY.Batch.SourceWindow");
	IJ.log("Spiky batch direct dispatcher reached; orientation=" + spikyBatchDirectOrientation + "; sourceWindow=" + spikyBatchDirectWindow);
	if (spikyBatchDirectWindow != "") {
		if (!isOpen(spikyBatchDirectWindow))
			exit("Spiky batch direct source window is not open: " + spikyBatchDirectWindow);
		selectWindow(spikyBatchDirectWindow);
		if (!startsWith(getInfo("window.type"), "Plot"))
			exit("Spiky batch direct source window is not a Plot: " + spikyBatchDirectWindow + " type=" + getInfo("window.type"));
	}
	if (spikyBatchDirectOrientation == "Positive")
		launchAnalysis(1);
	else if (spikyBatchDirectOrientation == "Negative")
		launchAnalysis(0);
	else if (spikyBatchDirectOrientation == "Auto")
		launchAnalysis(-1);
	else
		exit("Unsupported Spiky batch peak-analysis orientation argument: " + spikyBatchDirectOrientation + ". Expected Auto, Negative, or Positive.");
	IJ.log("Spiky batch direct dispatcher finished launchAnalysis for sourceWindow=" + spikyBatchDirectWindow);
	exit();
}

function testDependencies(Test) {
	print("Starting "+sVer);
	print(sCop);
	if (Test) {
		print("Testing dependencies...");
		isHRtime = testLib("HRtime"); 
		isKD = testLib("key_Down");
		isSGolay = testSG();
		call("ij.Prefs.set", "PCCV.HRtime",isHRtime);
		call("ij.Prefs.set", "PCCV.KD",isKD);
		call("ij.Prefs.set", "PCCV.Golay",isSGolay);
	} else print("Dependencies...");
	print("HRtime.jar :"+isHRtime);
	print("key_Down.jar :"+isKD);
	print("SavitzkyGolayFilter.class :"+isSGolay);
	if (!(isHRtime && isKD && isSGolay)) {
		print("Not all dependencies found but note that some are only optional");
		print("tips: Intall them to improve functionalities");
		print("Then:\n - restart ImageJ (or \"Refresh Menus\" in help menu)");
		print(" - use \"test dependencies\" to update settings.");
	}
	call("ij.Prefs.set", "SPIKY.first",false);
	return true;
}

function testSG() {
	isSGolay = testLib("Time_Noise_Reduce");
	if (!isSGolay)
		ret = "INFO: Time_Noise_Reduce class not found";
	if (isSGolay){ 
		isSGolay = testLib("SavitzkyGolayFilter");
		if (!isSGolay)
			ret = "INFO: SavitzkyGolayFilter.class not found";
	}
	if (isSGolay) { 
		isSGolay = testLib("Jama.Matrix");
		if (!isSGolay)
			ret = "INFO: Matrix.class (from JAMA package) not found";
	}
	if (!isSGolay) {
		print(ret);
		print("TIPS: Considere to install it to access Savitzky-Golay 3D filter!");
		print("For more info, go to: https://orangepalantir.org/ijplugins/index2.chy");
	}
	return isSGolay;
}

// click right menu
var pmCmds = newMenu("Popup Menu", newArray("Plot Result/Profile","Plot Result from Wand","-","Peak analysis","-","auto Fill for IM","Isochronal map", "Parameter map","Vector map","Vector histogram","-","Measure speed","Starting point","Greylevel filter","Get histogram","Derivative signal","-","Options","About"));

// click right menu, (ctrl click)
macro "Popup Menu" {
	getCursorLoc(xx1, yy1, zz1, modifiers);
	cmd = getArgument();
	if (cmd!="-" && cmd == "Plot Result/Profile") plotResult();
	if (cmd!="-" && cmd == "Plot Result from Wand") plotWand();
	if (cmd!="-" && cmd == "Peak analysis") launchAnalysis(-1);
	if (cmd!="-" && cmd == "auto Fill for IM") print(autoFill());
	if (cmd!="-" && cmd == "Isochronal map") Isochrone_map();
	if (cmd!="-" && cmd == "Parameter map") Parameter_map();	
	if (cmd!="-" && cmd == "Measure speed") Measure();
	if (cmd!="-" && cmd == "Starting point") {
		Pstart = getPixel(xx1, yy1);
		Pend=0; /*Debug=true; // utilisation des valeurs de B&C
		if (isOpen("B&C")) {
			tag = getTag("Display range");
			if (Debug) print(tag);
			if (tag!="") {
				ret=getBoolean("Would you also applyed limit set in B&C window?");
				if (ret) {
					Pend = parseFloat(substring(tag, 1+indexOf(tag, "-")));
					if (Debug) print(Pend);
				}		
			}
		} */
		run("Subtract...", "value=" + (Pstart-1));
		if (nSlices >1) 
			Stack.getStatistics(Count, mean, min, max, sd);
		else 
			getStatistics(Count, mean, min, max, sd);	
		if (Debug) print(Pend-Pstart);
		if (Pend > 0)
			GreylevelFilterMinMax(0,Pend-Pstart);
		else GreylevelFilterMinMax(0,max);
		resetMinAndMax();
	}
	if (cmd!="-" && cmd == "Vector map") Vector_map();
	if (cmd!="-" && cmd == "Vector histogram") Vector_map_hist(1);
	if (cmd!="-" && cmd == "Get Histogram") { 
		requires("1.52f");
		Dialog.create("Histogram"); {
			Dialog.addCheckbox("Remove zero ", 1);
			Dialog.show();
			noZero = Dialog.getCheckbox();
		}
setBatchMode(true);
		run("Duplicate...", "title=tempHist"); 
		getDimensions(largeur, hauteur, channels, slices, frames);
		N = getHisto(largeur, hauteur, noZero);
		Array.getStatistics(N, minHisto, maxHisto, meanHisto, stdHisto);
		Plot.create("Magnitude histogram","Amplitude","Counts");
		Plot.setColor("black","lightGray");
		Plot.addHistogram(N, 0);
		Plot.addText("N: "+ lengthOf(N)+ "pts, Mean: "+ meanHisto +", SD: " + stdHisto + ", min: " + minHisto + ", max: " + maxHisto, 0.2, 0);
		Plot.show;
		// Plot.update();		
setBatchMode(false);
	}
	
	if (cmd!="-" && cmd == "Drift removal") Drift_Removal_fromMenu();
	if (cmd!="-" && cmd == "Greylevel filter") GreylevelFilter();
	if (cmd!="-" && cmd == "Derivative signal") {
// setBatchMode(true);		//do not use with : eval("script","WindowManager.getActiveWindow()
		if ( !startsWith(getInfo("window.type"), "Plot"))
			plotResult();
		Plot.getValues(arrayX, arrayY); 
		smooth = call("ij.Prefs.get", "SPIKY.PeakAna.smooth",-1);
		if (smooth==-1) {
			videoid = getImageID();
			// print(videoid);
			if (getVersion()>"1.51s" ) {
				Vaxis = eval("script","WindowManager.getActiveWindow().getPlot().getLabel('y')");
				strVaxis = extractLabel(Vaxis,"l");
				strVunit = extractLabel(Vaxis,"u");
			}
			detectXunitfromPlot(videoid);		
			echant = roundn(1/(arrayX[lengthOf(arrayX)-1] - arrayX[lengthOf(arrayX)-2])*Tprop,0);
			smooth = roundn(echant/100,0);
			if (Debug) print(smooth);
		} 
		if (smooth>=1) 
			arrayY = AdjFilter(arrayY,smooth);
		derivArray = newArray(lengthOf(arrayY));
		CalcDerivative(arrayX, arrayY, derivArray, 1);
		//Deallocate
		arrayX = 0;
		arrayY = 0;
		derivArray = 0;
// setBatchMode(false);
	}
	if (cmd!="-" && cmd == "Options") Options();
	if (cmd!="-" && cmd == "About") About();
}

// id + text C800Tf207N		// C800 = red		// Txyssc	ss=size
macro "Plot Result/Profile Action Tool - C000D12D13D14D15D16D17D18D19D1aD1bD1cD1dD1eD29D2eD38D39D3eD46D47D48D4eD55D56D5eD65D66D67D6eD77D78D79D7eD89D8aD8bD8eD9bD9cD9eDaaDabDacDaeDb9DbaDbeDc8Dc9DceDdeC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfffC800Te607T" {
	plotResult();
}

macro "Goto_Next_Peak Action Tool - C000D12D13D14D15D16D17D18D19D1aD1bD1cD1dD1eD29D2eD38D39D3eD46D47D48D4eD55D56D5eD65D66D67D6eD77D78D79D7eD89D8aD8bD8eD9bD9cD9eDaaDabDacDaeDb9DbaDbeDc8Dc9DceDdeC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfffC800Ta207GC800Tf207o" {
	str = gotoNextPeak();
	showStatus(str);
}

function gotoNextPeak() {
	ret = findNextPeak();
	if (ret[0] == -1)  return "no Min found";
	if (ret[0] <= 0) return "Found no peaks";
	setSlice(ret[0]);
	if (sensAna==1) return "Positive peak found";
	else return "Negative peak found";
	return "ERROR";
}

function findNextPeak() {
	// select last image/stack => avoid Log/dialog windows.
	selectImage(getImageID());

	Winfo=getInfo("window.type");
	if ( ! startsWith(Winfo, "Image")) {
		exit("<html>"
			 +"<h1>Find_Next_Peak</h1>"
			 +"<u>Error</u>: Selected window isn't suitable for this tool."
			 +"<ul>"
			 +"<li>tip: Find_Next_Peak works only on <b>Z-stack images</b>"
			 +"</ul>");
	}
	init_XYT_values();
	tolerancePerCent = call("ij.Prefs.get", "SPIKY.PeakAna.tolerance",15);
	ret=newArray(-1,-1,-1); // max, min, min
	 
	if (slices==1) {
		if (frame == frames) frame = 1;
		start = frame + 1;
		end = frames;
	} else  {
		if (slice == slices)	slice = 1;
		start = slice + 1;
		end = slices;
	}
	
	if (Debug)  print("start at "+start);
	// detect sens de l'analyse
	Ztab = GetZprofile(start, end);
	Array.getStatistics(Ztab, Zmin, Zmax, Zmean, ZstdDev);
	// print("Image:mean="+Zmean+" max="+Zmax+" min="+Zmin+" sd="+ZstdDev);		
	if ((Zmax - Zmean) < (Zmean-Zmin))
		sensAna = 0; 		// neg
	else sensAna = 1; 	// pos
	
	tolerance=(Zmax-Zmin)*tolerancePerCent/100;
	if (Debug)   print("tolerance is "+tolerance);
	if (sensAna==1) minLocs = Array.findMinima(Ztab, tolerance);
	else minLocs = Array.findMaxima(Ztab, tolerance);
	if (minLocs.length>0) {
		minLocs = Array.sort(minLocs);
		if (Debug)   print("Found "+minLocs.length+" min");

		//temps du firstmin
		if (Debug)   print("nextMin at "+(start+minLocs[0]));
		Ztab = Array.slice(Ztab,minLocs[0],Ztab.length);
		if (sensAna==1) maxLocs = Array.findMaxima(Ztab, tolerance);
		else maxLocs = Array.findMinima(Ztab, tolerance);
		maxLocs = Array.sort(maxLocs);
		ret[0]=0;
		ret[1] = minLocs[0]+start;
		if (maxLocs.length>0) {
			if (Debug)  print("Found "+maxLocs.length+" max");
			ret[0] = (start+minLocs[0]+maxLocs[0]);
			//temps du nextmin
			if (minLocs.length>1) {
				ret[2] = minLocs[1]+start; 
				return ret;
				// showStatus("Found "+maxLocs.length+" peaks, Max at "+found);
			} else return ret;
		} else return ret;
	} else return ret;
	return ret;
}

function GetZfromWand(x, y) {
	Stack.getPosition(channel, slice, frame);
	tol=eval("script","WandToolOptions.getTolerance()");
	mode=eval("script","WandToolOptions.getMode()");
	Ztab = newArray(nSlices);
	for(zi=1; zi<=nSlices; zi++) {
		setSlice(zi);
		doWand(x, y, tol, mode);
		getStatistics(area, mean);
		Ztab[zi-1] = area;
	}
	Stack.setPosition(channel, slice, frame);
	return Ztab;
}

function GetZprofile(start, end) {
	Stack.getPosition(channel, slice, frame);
	Ztab = newArray(end-start+1);
	for(zi = start; zi <= end; zi++) { //yi
		setSlice(zi);
		 // setZCoordinate(zi-1);
		getStatistics(area, mean);
		Ztab[zi-start] = mean;
	}
	Stack.setPosition(channel, slice, frame);
	return Ztab;
}

var sCmds = newMenu("Peaks_Analysis Menu Tool", newArray("Plot Result/Profile","-","Peak analysis","-","Isochronal map","Parameter map","Vector map")); 

macro "Peaks_Analysis Menu Tool -  C000C111C222C333C444C555C666D2fD5fD8fDefC666D0eD1eD2eD3eD4eD5eD6eD7eD8eD9eDaeDbeDbfDceDdeDeeDfeC666D0dC777D0cC777D0bC777D96C777D0aC777D1cD2cD3cD4cD5bDa8DdcDecDfcC777D09C777D08D69C777D86DbbC777D04D07D6aC777D76Da7C777D03D06C777C888D02D05D77C888DbaC888Da9C888C999DccC999D68DcbC999CaaaDaaCaaaD78CaaaD5cCaaaD97CaaaD6bCaaaD5aCaaaD79Da6DbcCbbbDabCbbbD4bD87D98CbbbD1dD2dD3dD4dD5dD6cD6dD7aD7bD7cD7dD88D89D8aD8bD8cD8dD99D9aD9bD9cD9dDacDadDb8DbdDcdDddDedDfdCbbbD67CbbbDb9CbbbCcccD13D16D19D22D23D24D25D26D27D28D29D2aD2bD33D36D39D43D46D49D52D53D54D55D56D57D58D59D63D66D73D82D83D84D85D93Da3Db2Db3Db4Db5Db6Db7Dc3Dc6Dc9Dd3Dd6Dd9De2De3De4De5De6De7De8De9DeaDebDf3Df6Df9CcccCdddDdbCdddD95CdddCeeeD01D11D21D31D41D51D61D71D81D91Da1Db1Dc1Dd1De1Df1CeeeD75DcaCeeeD3bCeeeD0fD12D14D15D17D18D1aD1bD1fD32D34D35D37D38D3aD3fD42D44D45D47D48D4aD4fD62D64D65D6fD72D74D7fD92D94D9fDa2Da4Da5DafDc2Dc4Dc5Dc7Dc8DcfDd2Dd4Dd5Dd7Dd8DdaDdfDf2Df4Df5Df7Df8DfaDfbDffCeeeCfffD00D10D20D30D50D60D70D80D90Da0Db0Dc0Dd0De0Df0" {
  cmd = getArgument();
	if (cmd!="-" && cmd == "Plot Result/Profile") plotResult();
	if (cmd!="-" && cmd == "Peak analysis") launchAnalysis(-1);	
	if (cmd!="-" && cmd == "Isochronal map") Isochrone_map();
	if (cmd!="-" && cmd == "Vector map") Vector_map();
	if (cmd!="-" && cmd == "Parameter map") Parameter_map();
}

macro "Peaks analysis" {
	Path = getDirectory("imagej") + "Config" + File.separator;
	if (File.exists(Path+"auto.txt")) loadConfigWithName(Path+"auto.txt"); // a creer
	
	Dialog.create("Parameters"); {
		sens = newArray("auto", "negative","positive");
		Dialog.addChoice("Sens of analysis", sens, sens[0]);
		Dialog.addMessage(sCop);
		Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky");
		Dialog.show();
		choice=Dialog.getChoice();
		if (startsWith(choice,sens[2]))
			launchAnalysis(1);
		else if (startsWith(choice,sens[1]))
			launchAnalysis(0);
		else launchAnalysis(-1); // auto
	}
}

macro "Peaks analysis Auto" {
	Path = getDirectory("imagej") + "Config" + File.separator;
	if (File.exists(Path+"auto.txt")) loadConfigWithName(Path+"auto.txt"); // a creer
	launchAnalysis(-1);
}

macro "Peaks analysis Negative" {
	Path = getDirectory("imagej") + "Config" + File.separator;
	if (File.exists(Path+"auto.txt")) loadConfigWithName(Path+"auto.txt"); // a creer
	launchAnalysis(0);
}

macro "Peaks analysis Positive" {
	Path = getDirectory("imagej") + "Config" + File.separator;
	if (File.exists(Path+"auto.txt")) loadConfigWithName(Path+"auto.txt"); // a creer
	launchAnalysis(1);
}

macro "Zoom_to_ROI Action Tool - C000C111De1C111D51C111C222DafDdfDf8C222D8dDfdC222C333D43Df3C333Dc0C333De9C333D70C333DbfDcfC333C444DaeDdeC444DfaC444D9dDadDddDedC444D0cD0fD1bD2aD39D3fD4eD5dD6cD7bC555Df7C555D1fD2fD3eD47D4dD5cD6bC555D52De2C555D48C555D61Dd1C555D8cDfcC555C666D44D6aDf4C666D8bDfbC666DbeDceC666D0eC666Df6C666C777D46Db0C777D80D9aDaaDdaDeaC777Df5C777D2eD3dD45D4cD5bDbdDcdC777Da9Dd9C777D7aC888D5aDb8Dc8C888D1eD2dD3cD4bC888D59C888D9cDacDbcDccDdcDecC888De8C999Da0C999D90C999D0dD1cD2bD3aD49C999D58D8aC999DbbDcbC999CaaaDe3CaaaDa8CaaaDbaDcaCbbbD69CbbbD53Dd8CbbbDc1CbbbD71CbbbCcccD93Da3Dd2CcccD1dD2cD3bD4aD83CcccDb3CcccD62CcccD84D94Da4Db4CdddD74Dc4CdddD73De7CdddD9bDabDdbDebCdddD57CdddD75D85D95Da5Db5Dc3Dc5CdddD92Da2CdddD54De4CdddD65CdddDd5CdddD76D86D96Da6Db1Db6Dc6CdddD81CeeeD66CeeeDd6CeeeDb9Dc9CeeeD64CeeeD77D82D87D97Da7Db7Dc7Dd4CeeeDb2CeeeD67D88D98De5CeeeD78Dd7CeeeDe6CfffD55D56D91Da1CfffD63CfffDd3CfffD72D99Dc2CfffD68D89CfffD79" {
	if ( !startsWith(getInfo("window.type"), "Plot") &&  !startsWith(getInfo("window.type"), "Histogram"))
		exit("<html>"
			 +"<h1>Zoom_to_ROI</h1>"
			 +"<u>Error</u>: Selected window isn't suitable for this tool."
			 +"<ul>"
			 +"<li>tip: Zoom_to_ROI works only on <b>plot (or histogram) </b>windows"
			 +"</ul>");	
	 if (selectionType == 0) ZoomToRoi();
	 else exit("<html>"
			 +"<h1>Zoom_to_ROI</h1>"
			 +"<u>Warning:</u> This tool need a rectangular selection");

}

macro "Zoom_to_ROI Action Tool Options" {
	if ( !startsWith(getInfo("window.type"), "Plot") &&  !startsWith(getInfo("window.type"), "Histogram"))
		exit("<html>"
			 +"<h1>Zoom_to_ROI</h1>"
			 +"<u>Error</u>: Selected window isn't suitable for this tool."
			 +"<ul>"
			 +"<li>tip: Zoom_to_ROI works only on <b>plot (or histogram) </b>windows"
			 +"</ul>");	
	 if (selectionType == 0) ZoomToRoiN("Zoom to ROI", true);
	 else exit("<html>"
			 +"<h1>Zoom_to_ROI</h1>"
			 +"<u>Warning:</u> This tool need a rectangular selection");
}

macro "Peak_fit Action Tool - C400D3fD5fD7fD9fDbfCcccCc33D4cCfccD11C147D7cCeccDe1Ce87Da0Db0C811D0aCdccD12D14Cd76Df6CeffDa1Ca99D3eD7eCdeeCbbbD4dC500D2fCcccCc54D07CfffD92Da9C68aD87Dd5CdeeCc99D4bC844D0eDfeCdddCe87D20D30D40D50D60D70D80D90Dc0Dd0Df2Df3Df4CfffDd4CaabDcbCeeeCcbbC400D4fD6fD8fDafDcfDdfCbcdDb2Cc34D5bCfeeDc2C68aD37D38D77Dd6CddeCc99D5cCa22D08CdddCe77Dc3CfffCb9aD1cCeeeCbccC600D0dCcddCc55D6bC988DdeCeeeD48Ce99Dd3Ca44DfaCbaaD1dCeffCdbbD18CcccCc33D7aD98CfccDb4C579DcaCeddD0fDb7DffCe87D10C833D1fDefCdddD5aCd77D6aCa9aD2eCeeeD47CbbcD8cD8dC700D0cCccdCd55Db5C89aD7dCcaaD1aC943DfbCabbDbbCcbcD7bCccdDa3Cd44Da7CfeeD00Df0Ce88D01De0Df1Cb43D02D06Ce77Df5CaaaD4eD6eD8eDaeDceC722DfdCcddD76Dc6Cd76Df7Ca88D5eD9eDbeCdabD99C877DeeCabbD6dCebbDd2CbccCc33D89C258Da2CeddC822D0bCdccCc55D05Cd9aD79Cc45D3cCa33D09Cc65Df8CdaaD88Cb55Df9CdbbD16CbcdD27D28C579DbaCd88Da6Cb89D3dDc5Cc65D03C9abD6cCdbbD8aCb43D04CcbcCcddD86Cd44Dc4C832DfcCd66Db6CeaaD97C977D1eCbbbD2dCebcDa8" { 
	requires("1.51s");
	if ( !startsWith(getInfo("window.type"), "Plot") &&  !startsWith(getInfo("window.type"), "Histogram"))
		exit("<html>"
			 +"<h1>Peak/Curve Fit</h1>"
			 +"<u>Error</u>: Selected window isn't suitable for fitting."
			 +"<ul>"
			 +"<li>tip: fitting works only on <b>plot (or histogram) </b>windows"
			 +"</ul>");	
	selectImage(getImageID());
	 if (selectionType == 0) {
setBatchMode(true);
		ZoomToRoiN("Fit ROI", false);
		Plot.getValues(x, y);
		selectWindow("Fit ROI");
		CloseW("Fit ROI");
setBatchMode(false);
		name = newArray(Fit.nEquations+1);
		formula = newArray(Fit.nEquations);
		for (i=0; i < Fit.nEquations; i++) {
			Fit.getEquation(i, name[i], formula[i]);
		}
//		name[i] = "
		Dialog.create("Fit Parameters");
		Dialog.addChoice("Name", name);
		Dialog.addMessage(sCop);
		Dialog.show();
		fitFunction = Dialog.getChoice();
		Fit.showDialog;
		 // Mono Exponential Decay Fit : y = y0 + a * exp -(x/t)
		 
/*		fitFunction = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Function","y = a+(b*exp(-x/c))");
		 // ExpDecay1 = "y = a+(b*exp(-x/c))";
		a = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Param_a",1);
		b = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Param_b",1);
		c = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Param_c",1);
		d = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Param_d",1);
*/		
		// initialFitValues=newArray(4); //valeurs de départ pour le fit
		// initialFitValues[0]=a;
		// initialFitValues[1]=b;
		// initialFitValues[2]=c;
		// initialFitValues[3]=d;
		
		// Fit.doFit(fitFunction, x, y, initialFitValues);
		val0 = x[0];
		if (startsWith(fitFunction,"Exponential")) {
			for (i=0; i < lengthOf(x); i++) {
				x[i] -= val0;
			}
		} /* */
		Fit.doFit(fitFunction, x, y);
		Fit.plot();
		//De-allocating
		x=0;  y=0;
		name = 0;
		formula = 0;
		
	 } 	 else exit("<html>"
			 +"<h1>Peak/Curve Fit</h1>"
			 +"<u>Warning:</u> This tool need a rectangular selection");
}

macro "Peak_fit Action Tool Options" { 
	// find_decay();
	curveFitOptions();
}

function find_decay() {
	ZoomToRoiN("Fit ROI", true);
	Plot.getValues(X,Y);
	fitFunction = "Exponential with Offset";
	Fit.doFit(fitFunction, X, Y);
	Fit.plot();
	//De-allocating
	X=0; Y=0;
}

var sCmds = newMenu("Spiky Menu Tool", newArray("Drift removal","2D FFT Plot","Filter Plot","Greylevel filter", "Peak simulator", "-", "Calibration", "Manage calibration", "Change Directory", "Create Calibration bar", "-","Analysis options", "Curve fit options", "Common options","Test dependencies","-","Load Config", "Save Config as...","-","Help","About")); 

macro "Spiky Menu Tool -  C000C111C222D28DbbC222C333C444D25Db8C444D29DbcC444C555D2aC555D24D2bD2cD2dD64D67D6aD6dDb4Db5Db6Db7DbdDf4Df7DfaDfdC555C666D18D38DabDcbC666C777D08D48D9bDdbC777C888D07D47D9aDdaC888D46Dd9C888D06D99C999D17D37DaaDcaC999D05D45D98Dd8C999CaaaD35Dc8CaaaD15Da8CaaaCbbbD27DbaCbbbCcccD19D39D54D57D5aD5dDacDccDe4De7DeaDedCcccD49DdcCcccD09D9cCcccCdddCeeeD01D11D21D31D41D51D61D71D81D91Da1Db1Dc1Dd1De1Df1CeeeD02D03D04D0aD0bD0cD0dD0eD0fD12D13D14D1aD1bD1cD1dD1eD1fD22D23D2eD2fD32D33D34D3aD3bD3cD3dD3eD3fD42D43D44D4aD4bD4cD4dD4eD4fD52D53D55D56D58D59D5bD5cD5eD5fD62D63D65D66D68D69D6bD6cD6eD6fD72D73D74D75D76D77D78D79D7aD7bD7cD7dD7eD7fD82D83D84D85D86D87D88D89D8aD8bD8cD8dD8eD8fD92D93D94D95D96D97D9dD9eD9fDa2Da3Da4Da5Da6Da7DadDaeDafDb2Db3DbeDbfDc2Dc3Dc4Dc5Dc6Dc7DcdDceDcfDd2Dd3Dd4Dd5Dd6Dd7DddDdeDdfDe2De3De5De6De8De9DebDecDeeDefDf2Df3Df5Df6Df8Df9DfbDfcDfeDffCeeeCfffD16D26D36Da9Db9Dc9CfffD00D10D20D30D50D60D70D80D90Da0Db0Dc0Dd0De0Df0" {
    cmd = getArgument();
	if (cmd!="-" && cmd == "2D FFT Plot" ) FFTplot();
	if (cmd!="-" && cmd == "Filter Plot" ) plotFilter();
    if (cmd!="-" && cmd == "Peak simulator" ) pkSim();
	if (cmd!="-" && cmd == "Load Config" ) loadConfig();
	if (cmd!="-" && cmd == "Save Config as...") saveConfig();
    if (cmd!="-" && cmd == "Drift removal") Drift_Removal_fromMenu();
    if (cmd!="-" && cmd == "Greylevel filter") GreylevelFilter();
	if (cmd!="-" && cmd == "Calibration") Calibration();
	if (cmd!="-" && cmd == "Manage calibration"){
		if (startsWith(getInfo("os.name"), "Windows"))
			exec("explorer.exe "+IJlocation); 
		else if (startsWith(getInfo("os.name"), "Linux"))	
			exec("xdg-open "+IJlocation);
		else if (startsWith(getInfo("os.name"), "Mac OS"))
			exec("open "+IJlocation);
    }
	 if (cmd!="-" && cmd == "Change Directory") {
		call("ij.io.DirectoryChooser.setDefaultDirectory", IJlocation);
		IJlocation=getDirectory("Choose a Directory");
	 }
	 if (cmd!="-" && cmd == "Create Calibration bar") {
		init_Common_values(); 
		createCalibrationBar(getImageID());
	 }
    if (cmd!="-" && cmd == "Analysis options") Options();
    if (cmd!="-" && cmd == "Common options") Common_options();
    if (cmd!="-" && cmd == "Curve fit options") curveFitOptions();
	if (cmd!="-" && cmd == "Test dependencies") testDependencies(true);
//    if (cmd!="-" && cmd == "Batch mode") batchMode();
	 if (cmd!="-" && cmd == "Help") {
			if (getInfo("os.name")=="Linux")
				exec ("sh","-c", "URL=\"https://pccv.univ-tours.fr/ImageJ/Spiky/\"; xdg-open $URL || sensible-browser $URL || x-www-browser $URL || gnome-open $URL || open $URL");
			else
				exec("open","https://pccv.univ-tours.fr/ImageJ/Spiky/");
	 }
    if (cmd!="-" && cmd == "About") About();
}

/********************** COMMON XYT *************************/
function init_XYT_values() {
	init_Common_values();
	if (nSlices==1)
		exit("<html>"
			 +"<h1>"+sVer+"</h1>"
			 +"<u>Warning</u>: This tool requires a stack");
			 // +"<ul>"
			 // +"<li>tip: You can provide <b>Z-stack images</b> or a <b>Result table</b>"
			 // +"</ul>");	
	if (slices>1 && frames>1)
		exit("<html>"
			+"<h1>"+sVer+"</h1>"
			+" <u>Error</u>: Not works on 4D image file!"
			+"<ul>"
			+"<li>tip: if this is an error, use <b>Sht+P</b> to correct it."
			+"</ul>");
	if (Debug) print("frames = "+frames);
	if (frames==1) {
		if (Debug) print("swapping slices/frames");
		frames = slices; slices = 1;
		Stack.setDimensions(channels, slices, frames);
	}
	Stack.getPosition(channel, slice, frame);
	Stack.getUnits(X, Y, Z, Tunits, Value);
	Tprop = calibrateTime(Tunits);
	if (Tprop !=0) fps = getFPS(Tprop);
	else exit("<html>"
			+"<h1>"+sVer+"</h1>"
			+" <u>Error</u>: no time unit!"
			+"<ul>"
			+"<li>tip: if this is an error, use <b>Sht+P</b> to correct it."
			+"</ul>");
	if (Debug) print("fps = "+fps);
	getVoxelSize(pixelW, pixelH, pixelD, unit);
	if (pixelD==1E-13) pixelD=0;
}

function calibrateTime(sTime) {
	if (startsWith(sTime,"h")) return 1/3600;
	if (startsWith(sTime,"min")) return 1/60;
	if (startsWith(sTime,"mn")) return 1/60;
	if (startsWith(sTime,"s")) return 1;
	if (startsWith(sTime,"ms")) return 1000;
	if (startsWith(sTime,"millis")) return 1000;
	if (startsWith(sTime,"us")) return 1000000;
	if (startsWith(sTime,"micros")) return 1000000;
	if (startsWith(strHunit, fromCharCode(0x00B5)+"s")) { return 1000000;	}	
	if (startsWith(sTime,"ns")) return 1000000000;
	return 0;
}

function getFPS(prop) {
	FI = Stack.getFrameInterval();
	if (FI==0 || isNaN(FI)) { // extract from FrameRate
		fps = Stack.getFrameRate();
		if (fps==0) { // Try extract from Info (AVI)
			if (Debug) print("FI = "+FI+"\nTrying to extract from Info (AVI)...");
			if ( lengthOf(getTag("Frame Rate:"))==0)
				return 0;
			else print("FPS found in INFO");
		} else 	if (prop==1) {
			FI = 1/fps;
			Tunits = "s";
			if (FI<0.1) {
				Tunits = "ms";
				FI = FI *1000;
			}
			Stack.setFrameInterval(FI);
			Stack.setTUnit(Tunits);
			} else {
				FI = prop/fps;
				Stack.setFrameInterval(FI);
			}
	} else fps = prop / FI;
	return fps;
}

/********************** COMMON Image function *************************/
function getHisto(largeur, hauteur, noZero) {
	tab = newArray(largeur*hauteur);
	i = 0;
	for (y=1; y<hauteur; y++) 
		for (x=1; x<largeur; x++) {
			val = getPixel(x,y);
			if (!isNaN(val)) {
				if (noZero == 1) {
					if (val != 0)
						tab[i++] = val;
				} else tab[i++] = val;
			}
		}
	return Array.trim(tab, i);	
}

function init_Common_values() {
	if ( nImages<1 ) {
		exit("<html>"
			 +"<h1>"+sVer+"</h1>"
			 +"<u>Warning</u>: There are no images open"
		);
	}	
	getDimensions(largeur, hauteur, channels, slices, frames);
	getPixelSize(unit, pixelW, pixelH);
	pixelW = roundn(pixelW, 7);
	pixelH = roundn(pixelH, 7);
	nom_ori = getTitle();
	Nbits = bitDepth();
}

function duplicateBlack(mapName, type) {
	run("Duplicate...", "title=["+mapName+"]"); 
	run("Select All"); 
	setBackgroundColor(0, 0, 0); run("Clear", "slice");	
	run("Select None");
	run(type);
}

function GreylevelFilterMinMax(lt,ht) {
	GreylevelFilterMinMaxEx(lt,ht,false);
}

function GreylevelFilterMinMaxEx(lt,ht,inside) {
	getDimensions(largeur, hauteur, channels, slices, frames);
	choix = 0;
	if (nSlices >1) {
		// Stack.getPosition(channel, slice, frame);
		choix = getBoolean("Process all "+ nSlices+" images?");
	}
	if (choix == 1) {
		for (zi = 0; zi < nSlices; zi++) {
			showProgress(zi/nSlices);			
//			setSlice(ii);
			setZCoordinate(zi);
			if (inside)
			for (xx=0;xx<largeur;xx++)
				for (yy=0;yy<hauteur;yy++) {
					val = getPixel(xx,yy);
					if ((val <= ht) && (val >= lt) )
						setPixel(xx,yy,0);
				}
			else
				for (xx=0;xx<largeur;xx++)
					for (yy=0;yy<hauteur;yy++) {
						val = getPixel(xx,yy);
						if ((val > ht) || (val < lt) )
							setPixel(xx,yy,0);
					}
		}
		// if (nSlices >1) 	Stack.setPosition(channel, slice, frame);
	} else {
		if (inside)
			for (xx=0;xx<largeur;xx++)
				for (yy=0;yy<hauteur;yy++) {
					val = getPixel(xx,yy);
					if ((val <= ht) && (val >= lt) )
						setPixel(xx,yy,0);
				}
		else
			for (xx=0;xx<largeur;xx++)
				for (yy=0;yy<hauteur;yy++) {
					val = getPixel(xx,yy);
					if ((val > ht) || (val < lt) )
						setPixel(xx,yy,0);
				}
			
	}
}

function GreylevelFilter() {
	init_Common_values();
	if (nSlices >1) 
		Stack.getStatistics(Count, mean, min, max, sd);
	else 
		getStatistics(Count, mean, min, max, sd);
	lt = min; ht = max; 
	if (isOpen("B&C")) {
		tag = getTag("Display range");
		if (Debug) print(tag);
		if (tag!="") {
			print(indexOf(tag, "- "));
			print(substring(tag, 0, indexOf(tag, "- ")));
			lt = parseFloat(substring(tag, 0, indexOf(tag, "- ")));
			ht = parseFloat(substring(tag, 1+indexOf(tag, "- ")));
		}
	} 
	Dialog.create("Thresholds"); {
		Dialog.addNumber("Low threshold",lt);
		Dialog.addToSameRow(); 
		Dialog.addNumber("High threshold",ht);
		Dialog.addCheckbox("Delete inside values", false);
		Dialog.addMessage("Tips: default values extracted from \"B&C tool\"");
		Dialog.addMessage(sCop);
		Dialog.show();	
		lt = Dialog.getNumber();
		ht = Dialog.getNumber();
		inside = Dialog.getCheckbox();
	}
	GreylevelFilterMinMaxEx(lt,ht,inside);

}

function createCalibrationBar(imageid) {
	if (bitDepth() == 24)
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: Doesn't work with RGB images !"
			 +"<ul>"
			 +"<li>tip: change type to 16 or 32 bit"
			 +"</ul>");	
			 
setBatchMode(true);
	init_Common_values();
	
	is_Calibrated = false;
	if (bitDepth() == 32) {
		Tunits = getTag("Calibration unit:");
		if ( lengthOf(Tunits)==0 )
			if ( lengthOf(getTag("Calibration"))>0 )
				Tunits = getTag(" Unit:");
		if ( lengthOf(Tunits)>0 ) {
			print("Debug: Tunits="+Tunits);
			prop = calibrateTime(Tunits);
			print("prop="+prop);
			factor =  1;
			if (prop !=0)
				is_Calibrated = true;
		}	
	} else if ( lengthOf(getTag("Calibration")) >0 ) {
		factor =  1/parseFloat(getTag("b:"));
		is_Calibrated = true;
		Tunits = getTag("Unit");
		Tunits = substring(Tunits, indexOf(Tunits,"\"")+1, lastIndexOf(Tunits,"\""));
		print("Tunits="+Tunits);
		prop = calibrateTime(Tunits);
		print("prop="+prop);
		print("factor="+factor);
	} 

	if (is_Calibrated) {
		print("Image is calibrated");
	}
	getStatistics(Count, mean, min, max, sd);
	if (max>5) decim=0;
	else decim=2;
	getLocationAndSize(xwin, ywin, dxwin, dywin);
	zoom = getZoom();
	run("Duplicate...", " ");
	call("ij.gui.ImageWindow.setNextLocation", xwin+dxwin, ywin);
	calid = getImageID();
	run("Select All");
	run("Clear", "slice");
	
setBatchMode(false);
	selectImage(imageid);
	run("Calibration Bar...", "location=[Lower Left] fill=None label=White number=5 decimal="+decim+" font=9 zoom="+ hauteur/150 +" bold overlay show");
	run("To ROI Manager");
	run("Hide Overlay");
	
	selectImage(calid);
	// setBatchMode("show"); 
	roiManager("Show All without labels");
	run("Canvas Size...", "width="+hauteur+" height="+hauteur+" position=Bottom-Left");
	run("Set... ", "zoom="+zoom*100);
	selectWindow("ROI Manager");
	run("Close");

}

/********************** Calibration Image tools *************************/
function getFileContents(profilename) {
 	filedestination = IJlocation + profilename ;
	if (! File.exists(filedestination + "-Calib"+".txt")) exit ("No calibration file.");
	return File.openAsString(filedestination + "-Calib"+".txt");
}

// Function giving the number (NumberOfProfiles) of profiles contained a file list (lprofile).
function getProfileNumber(lprofile) {
	NumberOfProfiles=0;
	for (i=0; i<lprofile.length; i++) {
     	showProgress(i,lprofile.length);
		if (endsWith(lprofile[i], "-Calib.txt") && lengthOf(lprofile[i]) > lengthOf("-Calib.txt")) NumberOfProfiles ++;
	}
	return NumberOfProfiles;
}

function saveMicroPref(profileName,profileContents) {
 	filedestination = IJlocation + profileName ;
	if (File.exists(filedestination + "-Calib"+".txt")) showMessageWithCancel ("A \"" + profileName + "\" Calib already exists. Overwrite it?");
	File.makeDirectory(IJlocation);
	if (!File.exists(IJlocation)) exit("Unable to create directory, something wrong in the ImageJ folder");
	pathProf = filedestination + "-Calib"+".txt";
	theprofile = File.open(pathProf);
	print (theprofile,profileContents);
	File.close(theprofile);
}

function InstalledProfiles() {
 	listoffiles=getFileList(IJlocation);
 	NumberOfProfiles=getProfileNumber(listoffiles);
 	if (NumberOfProfiles !=0) {
 		var shortCat = newArray (NumberOfProfiles);
 		nbProf=0;
 		for (i=0; i<listoffiles.length; i++) {
     		showProgress(i,listoffiles.length);
			if (endsWith(listoffiles[i], "-Calib.txt") && lengthOf(listoffiles[i]) > lengthOf("-Calib.txt")) {
				shortCat [nbProf]=replace(listoffiles[i], "-Calib.txt", "");
				nbProf++;			
			}
		}
		// shortCat[nbProf++] = "-";
		// shortCat[nbProf++] = "New calibration";
		// shortCat[nbProf] = "Manage calibration";
	} else {
 		var shortCat = newArray ();
 	}
	return shortCat;
}

function Calibration()  {
	init_Common_values();
	
	TPIX = call("ij.Prefs.get", "SarcOptix.VideoCalibPixSiz",0);
	Profiles = InstalledProfiles();
	Dialog.create("Calibration");
	Dialog.addMessage("Pixel size is: "+ pixelW + " " + unit);
	if (TPIX != 0)
		Dialog.addNumber("Last pixel calibration was: ", TPIX, 9, 10, ""+fromCharCode(0x00B5)+"m");
	else Dialog.addNumber("Pixel size: ", 0, 4, 6, ""+fromCharCode(0x00B5)+"m");
	if (NumberOfProfiles > 0) {
		items = newArray(	" Use above calibration    ", " New calibration from line", " Use saved calibration        ");
		Dialog.addRadioButtonGroup("Choose: ", items, 3, 1, items[0]);
		Dialog.addChoice("", Profiles);
	} else {
		items = newArray(	" Use above calibration    ", " New calibration from line");
		Dialog.addRadioButtonGroup("Choose: ", items, 2, 1, items[0]);
	}
	Dialog.addMessage("Path: "+IJlocation); // +"\ntips : Use 'Common options' to change");
	Dialog.addMessage(sCop);
	Dialog.show();
	TPIX = Dialog.getNumber();
	chargerCalib = Dialog.getRadioButton();
	
	if (chargerCalib == items[0]) {
		run("Properties...", "unit=um pixel_width="+TPIX+" pixel_height="+TPIX+"");
	} 
	if (NumberOfProfiles > 0) {
		if (chargerCalib == items[2]) {
			TPIX = parseFloat(getFileContents(Dialog.getChoice()));
			um = getInfo("micrometer.abbreviation");
			run("Properties...", "unit="+um+" pixel_width="+TPIX+" pixel_height="+TPIX+"");
		}
	}
	if (chargerCalib == items[1]) {
		run("Line Width...", "line=1"); setTool("line");
		getLine(x1, y1, x2, y2, lineWidth);
		while (x1 == -1) {
			waitForUser( "Calibration","Please draw a line to calibrate and then click OK");
			getLine(x1, y1, x2, y2, lineWidth);
		}
		lineLength = sqrt (((y2-y1)*(y2-y1))+((x2-x1)*(x2-x1)));

		Dialog.create("Calibration");
		Dialog.addMessage("Pixel size is: "+ pixelW + " " + unit + "\nline length is: "+ lineLength + " pixels");
		Dialog.addMessage("New calibration :");
		Dialog.addNumber("Line length ", 100, 7, 10, ""+fromCharCode(0x00B5)+"m");
		Dialog.addString("Enter a name to save", "", 20);
		Dialog.addMessage("Path: "+IJlocation);
		Dialog.addMessage(sCop);
		Dialog.show();
		CalTool = Dialog.getNumber();
		Name = Dialog.getString();
		// run("Line Width...", "line=1"); setTool("line");
		// getLine(x1, y1, x2, y2, lineWidth);
		// while (x1 == -1) {
			// waitForUser( "Calibration","Please draw a line corresponding to "+CalTool+" "+fromCharCode(0x00B5)+"m and then click OK");
			// getLine(x1, y1, x2, y2, lineWidth);
		// }
		// lineLength = sqrt (((y2-y1)*(y2-y1))+((x2-x1)*(x2-x1)));
		if (Debug)
			print("linelength = "+lineLength);
		TPIX = CalTool / lineLength;
		run("Properties...", "unit=um pixel_width="+TPIX+" pixel_height="+TPIX+"");
		if ( lengthOf(Name) > 0)
			saveMicroPref (Name, ""+TPIX);
	}
	call("ij.Prefs.set", "SarcOptix.VideoCalibPixSiz",TPIX);
}
/********************** COMMON PLOT *************************/
function ZoomToRoi() {
	ZoomToRoiN("Zoom to ROI", false);
}

function ZoomToRoiN(name,  Xoffset) {
	requires("1.51s");
	Plot.getValues(arrayX, arrayY); //récupération des valeurs du plot
	getSelectionBounds(xmin, ymin, w, h);
	ymin += h;
	xmax = xmin + w;
	ymax = ymin - h;
	toScaled(xmin, ymin);
	toScaled(xmax, ymax);
	imin = findIndice(arrayX, xmin); 
	if (xmax >arrayX[lengthOf(arrayX)-1])
		imax=lengthOf(arrayX)-1;
	else imax = findIndice(arrayX, xmax); 
	// print(imin);
	// print(imax);
	X = newArray(imax-imin+1);
	Y = newArray(imax-imin+1);
	if (Xoffset) {
		val = arrayX[imin];
		for (i=imin;i<=imax;i++) {
			X[i-imin]=arrayX[i]-val;
			Y[i-imin]=arrayY[i];
		}
	} else
		for (i=imin;i<=imax;i++) {
			X[i-imin]=arrayX[i];
			Y[i-imin]=arrayY[i];
		}
	// name = getInfo("window.title");
	Vaxis = eval("script","WindowManager.getActiveWindow().getPlot().getLabel('y')");
	strVaxis = extractLabel(Vaxis,"l");
	strVunit = extractLabel(Vaxis,"u");
	if (Debug) {
		IJ.log("Y label: " + strVaxis);
		IJ.log("Y unit: " + strVunit);
	}
	Haxis = eval("script","WindowManager.getActiveWindow().getPlot().getLabel('x')");
	strHaxis = extractLabel(Haxis,"l");
	strHunit = extractLabel(Haxis,"u");
	if (Debug) {
		IJ.log("Y label: " + strHaxis);
		IJ.log("Y unit: " + strHunit);
	}
	txtVunit = " ("+strVunit+") ";
	txtHunit = " ("+strHunit+") ";

	Plot.create(name, " "+strHaxis + txtHunit, " "+strVaxis + txtVunit);
	Plot.setColor("blue");
	Plot.add("line", X, Y); 
	Plot.show;	
	//De-allocating
	arrayX=0;  arrayY=0; X=0; Y=0;
}

function plotfromResult() {
	// test si srcName exists
	offset=false;
	if (Debug) print(getInfo("window.type"));
	if ( startsWith(getInfo("window.type"), "ResultsTable"))  {
		headings = split(Table.headings,"	");
		// if (headings[0] == " ") 
		if (headings.length < 2) {
			exit("<html>"
				+"<h1>Spiky</h1>"
				+"<u>Warning</u>: Less than 2 columns"
				+"<ul>"
				+"<li>tip: you need at least 2 columns to make a plot !"
				+"</ul>");	
		} else if (headings.length > 2) {
			if (headings.length == 3 && headings[0] == " ") {
				Xst = headings[1];
				Yst = headings[2];
				Y2 = headings[0];
				val = Table.get(Xst, 0);
				if (val > 1) 
					offset = getBoolean("X values doesn't start from 0, reset to 0 ?");
			} else {
				Dialog.create("Data to plot"); {
					Dialog.addChoice("Header for X", headings);
					Dialog.addChoice("Header for Y", headings);
					if (headings.length >= 3) {
						Dialog.addChoice("Header for Y2", headings);
					} else Y2 = headings[0];
					Dialog.addCheckbox("Offset X values", true);
					Dialog.addMessage(sCop);
					Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky");
					Dialog.show();
					Xst = Dialog.getChoice();
					Yst = Dialog.getChoice();
					if (headings.length >= 3) {
						Y2 = Dialog.getChoice();
					}
					offset=Dialog.getCheckbox();
				}
			}
		} else {
			Xst = headings[0];
			val = Table.get(Xst, 0);
			if (val >0) 
				offset = getBoolean("X values doesn't start from 0, reset to 0 ?");
			Yst = headings[1];
			Y2 = headings[0];
		}
		if (Xst=="") exit();
		for (Xi=0; Xi<headings.length; Xi++)
			if (Xst == headings[Xi])
				break;
		X = recupPlotArray(srcName, headings[Xi], offset);
		if (Yst=="") exit();
		for (Yi=0; Yi<headings.length; Yi++)
			if (Yst == headings[Yi])
				break;
		Y = recupPlotArray(srcName, headings[Yi],false);

		Plot.create(srcName+"-Plot", " "+Xst+" ", " "+Yst+" ", X, Y);
		Plot.setLineWidth(1);
		Plot.setColor("black");
		if (Y2!=headings[0]) {
			for (Y2i=0; Y2i<headings.length; Y2i++)
				if (Y2 == headings[Y2i])
					break;
			Y2 = recupPlotArray(srcName, headings[Y2i],false);
			// Plot.setColor("red");
			Plot.add("line", X, Y2);
		}
		Plot.show();
	} else 
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: Selected window doesn't seems to be a table"
			 +"<ul>"
			 +"<li>tip: ResultToPlot works only on <b>Result table</b>"
			 +"</ul>");	
}

function extractLabel(str,type) {
	if (lengthOf(str)>0) {
		nLp = lastIndexOf(str, ")");
		nRp = lastIndexOf(str, "(");
		if (nRp == -1) {
			nLp = lastIndexOf(str, "]");
			nRp = lastIndexOf(str, "[");
		}
		if (nLp !=-1 && nRp !=-1) 
			if (nLp > nRp) {
				if (type=="u") return substring(str, nRp+1, nLp);
				if (type=="l") 
					if (nRp-1>0) return substring(str, 0, nRp-1);
			}
		if (type=="l") return str;
	}
	return "";
}

function detectXunitfromPlot(videoid) {
	selectImage(videoid);
	if (getVersion()>"1.51s") {
		Haxis = eval("script","WindowManager.getActiveWindow().getPlot().getLabel('x')");
		strHaxis = extractLabel(Haxis,"l");
		strHunit = extractLabel(Haxis,"u");
		if (Debug) {
			IJ.log("X label: " + strHaxis);
			IJ.log("X unit: " + strHunit);
		}
	}
	// detection auto X units
	Tprop = calibrateTime(strHunit);
	if (Debug) IJ.log("Tprop = "+Tprop);
	if (Tprop == 0) {
		Dialog.create("Analysis setup"); {
			Dialog.addMessage("Spiky didn't succeed to find time unit");
			items2 = newArray("s","ms",fromCharCode(0x00B5)+"s","ns");
			Dialog.addString("Label:", strHaxis); 
			Dialog.addNumber("Frame interval:", 1);
			Dialog.addChoice("Time unit is ", items2, "s");
			Dialog.addMessage(sCop);
			Dialog.show();
			FI = Dialog.getNumber();
			if (FI != 1) 
				strHaxis = "/"+FI+" "+ Dialog.getString();
			else strHaxis = Dialog.getString();
			strHunit = Dialog.getChoice();
			Tprop = calibrateTime(strHunit);
	 		Tprop /= FI;
		}
	}
}

function plot3Dimage(videoid) {
	selectImage(videoid);
	if (Debug) print("found image");
	init_XYT_values();
	if (startsWith(unit,"pixel")) 
		run("Properties...", "unit=UA");
	run("Plot Z-axis Profile");
	if (fps != 0)
		Plot.setXYLabels(" time ["+ Tunits+"] ", " Mean [UA] ");
	else Plot.setXYLabels(" Frame ", " Mean [UA] ");
} 	

function plotResult() {
	Winfo=getInfo("window.type");
	if ( ! startsWith(Winfo, "ResultsTable")) {	
		// select last image/stack => avoid Log/dialog windows.
		selectImage(getImageID());
		Winfo=getInfo("window.type");
	}	
	if (Debug) print(Winfo);
	if ( startsWith(Winfo, "ResultsTable")) {
		srcName = getInfo("window.title");
		strVaxis = " Amp ";
		strVunit = "UA";
		txtVunit = " ("+strVunit+") ";
		plotfromResult();
	} else {
		if ( startsWith(Winfo, "Image")) {
			srcName = getInfo("window.title");
			plot3Dimage(getImageID());
		} else {
			if (lengthOf(Winfo) > 0)
			exit("<html>"
				 +"<h1>Spiky</h1>"
				 +"<u>Warning</u>: selected windows isn't correct"
				 +"<ul>"
				 +"<li>tip: Use a <b>Z-stack images</b> or select a <b>Result table</b>"
				 +"</ul>");
			else
			exit("<html>"
				 +"<h1>Spiky</h1>"
				 +"<u>Warning</u>: There are no images open or image is buzy"
				 +"<ul>"
				 +"<li>tip 1: Open a <b>Z-stack images</b> or select a <b>Result table</b>"
				 +"<li>tip 2: wait for the job to finish or cancel it"
				 +"</ul>");
		}
	}
}

function plotWand() {
	init_XYT_values();
	Ztab = GetZfromWand(xx1, yy1);
	xtab = newArray(nSlices);
	for(zi=1; zi<=nSlices; zi++) {
		xtab[zi-1]=FI*(zi-1);
	}
	// Plot.setXYLabels(" time ["+ Tunits+"] ", " Mean [UA] ");
	Plot.create("Area plot", " time ["+ Tunits+"] "," area ["+ unit+"²] ",xtab,Ztab);
}

function recupPlotArray(nomTable, nomColonne, offset) {
//fonction pour récupérer les data d'un plot deja affiché dans un array
// TableOuPlot à 0 pour table ; à 1 pour plot;
	selectWindow(nomTable);
	arrayColonne = newArray(getValue("results.count"));
	val = getResult(nomColonne, 0);
	if (val > 0 && offset) {
		for(i=0; i<getValue("results.count"); i++) 
			arrayColonne[i] = getResult(nomColonne, i) - val;
	} else 
		for(i=0; i<getValue("results.count"); i++) 
			arrayColonne[i] = getResult(nomColonne, i);		
	return arrayColonne;
}

/********************** Peak Simulation *************************/
macro "Make simulation" {
   pkSim();
}

function dist(x1,y1,x2,y2){
	return sqrt(((y2-y1)*(y2-y1))+((x2-x1)*(x2-x1)));
}

function pkSim() {
   ver = getVersion();
   
   echant = call("ij.Prefs.get", "SPIKY.SIM.echant",1);
   inter = call("ij.Prefs.get", "SPIKY.SIM.inter",1000);
   Var = call("ij.Prefs.get", "SPIKY.SIM.var",1);
   nPks = call("ij.Prefs.get", "SPIKY.SIM.nPks",3);
   amp = call("ij.Prefs.get", "SPIKY.SIM.amp",2);
   rise = call("ij.Prefs.get", "SPIKY.SIM.rise",0.05);
   fall = call("ij.Prefs.get", "SPIKY.SIM.fall",0.005);
   sht = call("ij.Prefs.get", "SPIKY.SIM.sht",200);
   basal = call("ij.Prefs.get", "SPIKY.SIM.basal",0.5);
   noise = call("ij.Prefs.get", "SPIKY.SIM.noise",10);
   X = call("ij.Prefs.get", "SPIKY.SIM.X",100);
	Y = call("ij.Prefs.get", "SPIKY.SIM.Y",100);
   Xsht = call("ij.Prefs.get", "SPIKY.SIM.Xsht",0);
	Ysht = call("ij.Prefs.get", "SPIKY.SIM.Ysht",0);
	
	Dialog.create("Peak simulator"); {
		Dialog.addNumber("Nb peaks", nPks);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		// Dialog.addNumber("Nb points / peak", nPts);
		Dialog.addNumber("Interval", inter, 0,6,"ms");
		Dialog.addNumber("Sampling", echant, 1, 6, "kHz");
		sens = newArray("negative","positive");
		Dialog.addChoice("Sens of peaks", sens, sens[Var]);
		Dialog.addNumber("Max amplitude", amp, 2, 6,"UA");
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addNumber("Baseline", basal, 2, 6,"UA");
		Dialog.addNumber("Rise", rise, 3, 6,"ms-1");
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addNumber("Fall", fall, 3, 6,"ms-1");
		Dialog.addNumber("Time shift", sht, 2, 6,"ms");
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addNumber("SNR", noise, 0, 2,"%");
		Dialog.addCheckbox("Make video", false);
		Dialog.addNumber("Width", X, 0, 3,"px");
		if (ver >= "1.52f") Dialog.addToSameRow();
		Dialog.addNumber("Height", Y, 0, 3,"px");
		Dialog.addNumber("Shift X center", Xsht, 0, 2,"%");
		if (ver >= "1.52f") Dialog.addToSameRow();
		Dialog.addNumber("Shift Y center", Ysht, 0, 2,"%");
		Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky");
		Dialog.addMessage(sCop);

		Dialog.show();

		nPks = Dialog.getNumber();
		inter = Dialog.getNumber();
		echant = Dialog.getNumber();
		if (startsWith(Dialog.getChoice(),sens[0]))
			Var = 0;
		else Var = 1;
		amp = Dialog.getNumber();
		basal = Dialog.getNumber();
		rise = Dialog.getNumber();
		fall = Dialog.getNumber();
		sht = Dialog.getNumber();
		noise = Dialog.getNumber();
		video = Dialog.getCheckbox();
		X = Dialog.getNumber();
		Y = Dialog.getNumber();
		Xsht = Dialog.getNumber();
		Ysht = Dialog.getNumber();
		call("ij.Prefs.set", "SPIKY.SIM.echant",echant);
		call("ij.Prefs.set", "SPIKY.SIM.inter",inter);
		call("ij.Prefs.set", "SPIKY.SIM.var",Var);
		call("ij.Prefs.set", "SPIKY.SIM.nPks",nPks);
		call("ij.Prefs.set", "SPIKY.SIM.amp",amp);
		call("ij.Prefs.set", "SPIKY.SIM.rise",rise);
		call("ij.Prefs.set", "SPIKY.SIM.fall",fall);
		call("ij.Prefs.set", "SPIKY.SIM.sht",sht);
		call("ij.Prefs.set", "SPIKY.SIM.basal",basal);
		call("ij.Prefs.set", "SPIKY.SIM.noise",noise);
		call("ij.Prefs.set", "SPIKY.SIM.Xsht",Xsht);
		call("ij.Prefs.set", "SPIKY.SIM.Ysht",Ysht);
		call("ij.Prefs.set", "SPIKY.SIM.X",X);
		call("ij.Prefs.set", "SPIKY.SIM.Y",Y);
	}
	if (Var==0) Var=-1;
	
setBatchMode(true);	
	Array.show("Results");
	decimal = call("ij.Prefs.get", "SPIKY.PeakAna.decimal",6);
	run("Set Measurements...", "  decimal="+decimal);
	setOption("ShowRowNumbers", false);
	nFrames = inter*echant;
	last=0;
	for (x=0; x<(sht*echant); x++) {
		setResult("Time [ms]", x, x/echant);
		val = basal + (random - 0.5) * noise * amp / 100;
		setResult("Values [UA]", x, val);
	}
	for (n=0; n<nPks; n++) {
		for (x=0;x<nFrames;x++) {
			t = (x)/echant;
			val = basal + Var*amp*(exp(-fall*t) - exp(-rise*t)) + last*exp(-fall*(t));
			//  add noise
			val += (random - 0.5) * noise * amp / 100; 
			setResult("Time [ms]", sht*echant +x+nFrames*n, sht+(x+nFrames*n)/echant);
			setResult("Values [UA]", sht*echant +x+nFrames*n, val);
		}
		last = val - basal;
	}
	IJ.renameResults("Simulated peak");
// parametres de l'analyse
	Tmax = log(rise/fall)/(rise-fall);
	print("Mathematical determination:");
	print("==========================");
	print("Time2Pk (ms) = "+Tmax);
	Amax = Var*amp*(exp(-fall*Tmax) - exp(-rise*Tmax));
	val = Amax; LW50=Tmax;
	while( val > Amax/2) {
		val = Var*amp*(exp(-fall*LW50) - exp(-rise*LW50));
		LW50--;
	}
	LW50 = Tmax - LW50;
	val = Amax; RW50 = Tmax;
	while( val > Amax/2) {
		val = Var*amp*(exp(-fall*RW50) - exp(-rise*RW50));
		RW50++;
	}
	RW50 -= Tmax;
	
	print("Apeak (UA) = "+(basal+Amax));
	print("Amplitude (UA) = "+Amax);
	print("Baseline = " + basal);
	print("FWHM (ms) = " + (LW50+RW50));
	print("LW50 (ms) = " + LW50);
	print("RW50 (ms) = " + RW50);
	print("SlopeMax2Pk = " + rise);
	print("SlopeMax2Bl = " + (-fall));

	if (video) {
		srcName = getInfo("window.title");
		headings = split(Table.headings,"	");
		if (headings.length > 1) {
			// X = recupPlotArray(srcName, headings[1], false);
			Ytab = recupPlotArray(srcName, headings[2], false);
		} else exit("error");
		
		// CloseW(srcName);
	
		newImage("Video", "32-bit black", 100, 100, nFrames);	// "32-bit black"
		vidId = getImageID();
		Stack.setXUnit("um");
		run("Properties...", "frame=["+(1/echant)+" ms]");

		// background Noise
		bgNoise = newArray(200);
		for (i=0; i<200; i++)
			bgNoise[i] = basal + (random - 0.5) * noise * basal / 100; 
			
		Xori = X*(0.5 + Xsht/200);
		Yori = Y*(0.5 + Ysht/200);
		for(y=0; y<Y; y++) {
			showProgress(y/100);
			for(x=0; x<Y; x++) {
				zstart = dist(Xori,Yori,x,y);  // distance from origin
				zstart += (random - 0.5) * 4 * zstart / 100;
				for(z=0; z<zstart; z++) {
					setZCoordinate(z);
					setPixel(x,y,bgNoise[z]);
				}
				for(z=zstart; z<nFrames; z++) {
					setZCoordinate(z);
					val = Ytab[z-zstart];
					val += (random - 0.5) * noise * Ytab[z-zstart] / 100;
					setPixel(x,y,val);
				}
			}
		} 
setBatchMode(false);		
		/* */
		// r=nFrames/8;
		// run("Gaussian Blur 3D...", "x="+r+" y="+r+" z="+r);
	}
	// plotResult(); 
 // launchAnalysis(-1); 
}

/********************** Peak Detection *************************/
function Common_options() {
	Dialog.create("Common Parameters"); {
		Dialog.addCheckbox("Debug mode", Debug);
		Dialog.addMessage(sCop);
		Dialog.show();
		Debug = Dialog.getCheckbox();
		call("ij.Prefs.set", "SPIKY.Debug", Debug);
	}
}

function Options() {
	ver = getVersion();
	tolerancePerCent = call("ij.Prefs.get", "SPIKY.PeakAna.tolerance",15);
	thresholdDetectionDEbPeak = call("ij.Prefs.get", "SPIKY.PeakAna.TTP.thresholdDetectionDEbPeak",5);
	smooth = call("ij.Prefs.get", "SPIKY.PeakAna.smooth",-1);
	//DISPLAY
	SPWHDP = call("ij.Prefs.get", "SPIKY.PeakAna.SPWHDP",1);
	DerivativeSig = call("ij.Prefs.get", "SPIKY.PeakAna.DerivativeSig",0);
	Dbaseline = call("ij.Prefs.get", "SPIKY.PeakAna.Dbaseline",1);
	DVmax = call("ij.Prefs.get", "SPIKY.PeakAna.DVmax",1);
	Dthreshold = call("ij.Prefs.get", "SPIKY.PeakAna.Dthreshold",1);
	
	items4 = newArray("Automatic","Manual");
	autoDetect = call("ij.Prefs.get", "SPIKY.PeakAna.autoDetect",items4[0]);
	ASfS  = call("ij.Prefs.get", "SPIKY.PeakAna.ASfS",0);
	SSSL = call("ij.Prefs.get", "SPIKY.PeakAna.SSSL",1);

	FW  = call("ij.Prefs.get", "SPIKY.PeakAna.FW",1);
	x1P = call("ij.Prefs.get", "SPIKY.PeakAna.x1P",20);
	x2P = call("ij.Prefs.get", "SPIKY.PeakAna.x2P",80);
		
	HW = call("ij.Prefs.get", "SPIKY.PeakAna.HW",1);
	
	summarize = call("ij.Prefs.get", "SPIKY.PeakAna.summarize",0);
	decimal = call("ij.Prefs.get", "SPIKY.PeakAna.decimal",6);
	Vmax = call("ij.Prefs.get", "SPIKY.PeakAna.Vmax",1);

	AUP = call("ij.Prefs.get", "SPIKY.PeakAna.AUP",1);
	decay = call("ij.Prefs.get", "SPIKY.PeakAna.decay",0);
	pdecay = call("ij.Prefs.get", "SPIKY.PeakAna.pdecay",66);
	
	ShowSumTable = call("ij.Prefs.get", "SPIKY.PeakAna.ShowSumTable",1);
	
	Dialog.create("Analysis Parameters"); {
		Dialog.addMessage("___________________________________  DETECTION  ___________________________________");
		Dialog.setInsets(15, 20, 0); 
		Dialog.addNumber("Min peak amplitude from baseline",tolerancePerCent, 0, 2,"%"); //valeur de diff entre haut et bas du pic
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addNumber("Start peak threshold ",thresholdDetectionDEbPeak,0,2,"%");
		Dialog.addChoice("Detection sens of analysis", items4, autoDetect);
		
		Dialog.addCheckbox("Automatic search for synchro", ASfS);
		
		Dialog.addMessage("Adj/Avg smoothing: ");	
		// Dialog.addToSameRow(); 
		Dialog.addNumber("0=none, -1=auto or any values ("+fromCharCode(0x00B1)+")",smooth,0,2,""); 
		
		// if (ver >= "1.52f") Dialog.addToSameRow(); 
		// Dialog.addNumber("Manual AAS (0=none)",smooth, 0,2,""+fromCharCode(0x00B1)+"n"); 
		
		Dialog.addMessage("___________________________________   DISPLAY   ___________________________________");
		Dialog.addCheckbox("New plot with highlighted peaks (red)", SPWHDP);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addCheckbox("Show derivative signal plot", DerivativeSig);
		
		Dialog.addMessage("Add on new plot:");
		Dialog.addCheckbox("baseline (blue)", Dbaseline);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addCheckbox("threshold (green)", Dthreshold);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addCheckbox("Slope max (magenta)", DVmax);

		tSSSL = newArray("raw","smoothed");
		Dialog.addRadioButtonGroup("Signal", tSSSL, 1, 2, tSSSL[SSSL]);
		// Dialog.addCheckbox("Show smoothed instead of raw signal", SSSL);

		
		Dialog.addMessage("______________________________   TABULATED OUTPUT   _______________________________");
		// if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addCheckbox("Full Width: 50%,", FW);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addNumber("and ",x1P, 0, 2,"%"); 
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addNumber("and ",x2P, 0, 2,"%"); 
		Dialog.addCheckbox("Half Width (Left width (LW) & Right width (RW) ", HW);

		Dialog.addCheckbox("Peak area", AUP);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addCheckbox("Slope max", Vmax);
		Dialog.addCheckbox("Compute decay", decay);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addNumber("% of peak max", pdecay);
		
		// Dialog.addCheckbox("Show summary table", ShowSumTable);
		// if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addCheckbox("Show statistics lines", summarize);
		// Dialog.addNumber("Decimal places (0-9)",decimal);
		Dialog.addNumber("Decimal places (0-9)", decimal, 0, 2, "")
		Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky/options.html");
		Dialog.addMessage(sCop);
		Dialog.show();
		
		tolerancePerCent = Dialog.getNumber();
		thresholdDetectionDEbPeak = Dialog.getNumber();
		autoDetect = Dialog.getChoice();
		ASfS = Dialog.getCheckbox();
		smooth = Dialog.getNumber(); 
		SPWHDP = Dialog.getCheckbox();
		DerivativeSig = Dialog.getCheckbox();
		Dbaseline = Dialog.getCheckbox();
		Dthreshold = Dialog.getCheckbox();
		DVmax = Dialog.getCheckbox();
		
		// SSSL = Dialog.getCheckbox();
		if (Dialog.getRadioButton()==tSSSL[0])	SSSL = 0;		else SSSL = 1;
				
		FW = Dialog.getCheckbox();
		x1P = Dialog.getNumber();
		x2P = Dialog.getNumber();
		
		HW= Dialog.getCheckbox();
		AUP = Dialog.getCheckbox();
		Vmax = Dialog.getCheckbox();
		decay = Dialog.getCheckbox();
		pdecay = Dialog.getNumber();
		
		ShowSumTable = true; // Dialog.getCheckbox();
		summarize = Dialog.getCheckbox();
		decimal = Dialog.getNumber();		
	}
		
	call("ij.Prefs.set", "SPIKY.PeakAna.SPWHDP",SPWHDP);
	call("ij.Prefs.set", "SPIKY.PeakAna.autoDetect",autoDetect);
	call("ij.Prefs.set", "SPIKY.PeakAna.ASfS",ASfS);
	call("ij.Prefs.set", "SPIKY.PeakAna.DVmax",DVmax);
	call("ij.Prefs.set", "SPIKY.PeakAna.Dbaseline",Dbaseline);
	call("ij.Prefs.set", "SPIKY.PeakAna.Dthreshold",Dthreshold);
	
	call("ij.Prefs.set", "SPIKY.PeakAna.tolerance",tolerancePerCent);
	call("ij.Prefs.set", "SPIKY.PeakAna.smooth",smooth);

	call("ij.Prefs.set", "SPIKY.PeakAna.SSSL",SSSL);
	call("ij.Prefs.set", "SPIKY.PeakAna.TTP.thresholdDetectionDEbPeak",thresholdDetectionDEbPeak)
	call("ij.Prefs.set", "SPIKY.PeakAna.FW",FW);
	call("ij.Prefs.set", "SPIKY.PeakAna.x1P",x1P);
	call("ij.Prefs.set", "SPIKY.PeakAna.x2P",x2P);
	call("ij.Prefs.set", "SPIKY.PeakAna.DerivativeSig",DerivativeSig);
	
	call("ij.Prefs.set", "SPIKY.PeakAna.HW",HW);

	call("ij.Prefs.set", "SPIKY.PeakAna.Vmax",Vmax);
	call("ij.Prefs.set", "SPIKY.PeakAna.AUP",AUP);
	call("ij.Prefs.set", "SPIKY.PeakAna.decay",decay);
	call("ij.Prefs.set", "SPIKY.PeakAna.pdecay",pdecay);
	call("ij.Prefs.set", "SPIKY.PeakAna.summarize",summarize);
	call("ij.Prefs.set", "SPIKY.PeakAna.ShowSumTable",ShowSumTable);
	call("ij.Prefs.set", "SPIKY.PeakAna.decimal",decimal)
	// OVA = "false"; if (VFreq) OVA = "true";
	// call("ij.Prefs.set", "OFS.TO",toString(TimeOut));
}

function curveFitOptions() {

	fitFunction = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Function","y = a+(b*exp(-x/c))+(d*exp(-x/e))");
	a = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Param_a",1);
	b = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Param_b",1);
	c = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Param_c",1);
	d = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Param_d",1);
	e = call("ij.Prefs.get", "SPIKY.PeakAna.FitFunction.Param_e",1);

	Dialog.create("Fit Parameters"); {
		Dialog.addString("fit function (with a,b,c,d,e constants)", fitFunction, 30);
		Dialog.addMessage("initial parameter for the fit");
		Dialog.addNumber("a", a);
		Dialog.addNumber("b", b);
		Dialog.addNumber("c", c);
		Dialog.addNumber("d", d);
		Dialog.addNumber("e", e);
		
		Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky/options.html");
		Dialog.show();
		
		fitFunction = Dialog.getString();
		a = Dialog.getNumber();
		b = Dialog.getNumber();
		c = Dialog.getNumber();
		d = Dialog.getNumber();
		e = Dialog.getNumber();
	}
	
	call("ij.Prefs.set", "SPIKY.PeakAna.FitFunction.Function",fitFunction);
	call("ij.Prefs.set", "SPIKY.PeakAna.FitFunction.Param_a",a);
	call("ij.Prefs.set", "SPIKY.PeakAna.FitFunction.Param_b",b);
	call("ij.Prefs.set", "SPIKY.PeakAna.FitFunction.Param_c",c);
	call("ij.Prefs.set", "SPIKY.PeakAna.FitFunction.Param_d",d);
	call("ij.Prefs.set", "SPIKY.PeakAna.FitFunction.Param_e",e);
	
}

function About()  {
	exit("<html>"
		+ "<table>"
			+"<tr>"
				+"<td>"
					+"<img src=\"https://pccv.univ-tours.fr/univtours-logo-short.png\" height=\"50\" width=\"90\" alt=\"UT\">" 
				+"</td>"
				+"<td>"
					+"<br>"
					+"<h1>"+sVer+"</h1>"
					+"<br>"
				+"</td>"
			+"</tr>"
			+"</table>"
		+"<ul>"
		+"<li>more information at https://pccv.univ-tours.fr/ImageJ"
		+"</ul>"
		+"<p>"+sCop
		+"<p>"
	);
}

//sens = 1 cont ; -1 relax
//renvoie l'indice qui correspond à la valeur la plus proche
function TTxPeaki(arrayY, indiceXpeak, YauPRCTGvoulu, sens) {
	i=indiceXpeak;
	if (Variation<0)  {
		while (arrayY[i] < YauPRCTGvoulu) {
			i += sens;
		}
		if ((i != lengthOf(arrayY)-1) && (i != 0))
			if ((arrayY[i+sens] - arrayY[i]) > (arrayY[i]-arrayY[i-sens]))
				i += sens;
	} else {
		while (arrayY[i] > YauPRCTGvoulu) {
			i += sens;
		}
		if ((i != lengthOf(arrayY)-1) && (i != 0))
			if ((arrayY[i] - arrayY[i+sens]) > (arrayY[i-sens]-arrayY[i]))
				i += sens;
	}
	return i;
}

//sens = 1 cont ; -1 relax			// valeur Y au pourcentage voulu de TTx
function TTxPeak(arrayX, arrayY, indiceXpeak, ampDuPeak, valeurAuPeak, pourcentage, sens) {
	// si Variation <0  alors AmpDuPeak <0
	YauPRCTGvoulu = valeurAuPeak - ((100-pourcentage) * ampDuPeak / 100 );	
	if (Debug) {
		print("[Ana]");
		print("sens = "+ sens);
		print("peak = "+ valeurAuPeak);
		print("percent = "+ pourcentage);
		print("indice = " + indiceXpeak);
		print("baseline = "+ valeurAuPeak - Variation*ampDuPeak);
		print("Amp = "+ ampDuPeak);
		print("Yvoulu = "+ YauPRCTGvoulu);
	}
	itemp = TTxPeaki(arrayY, indiceXpeak, YauPRCTGvoulu, sens);
	// Interpolation 
	if (interpolate) {
		if ( itemp > (lengthOf(arrayX)-2))
			return arrayX[itemp];
		if ( itemp < 1)
			return arrayX[itemp];
		PeakArrayX = newArray(3);
		PeakArrayY = newArray(3);
		for(jj=-1; jj<2; jj++) {
			PeakArrayX[1+jj] = arrayX[itemp+jj];
			PeakArrayY[1+jj] = arrayY[itemp+jj];
		}
		fitFunction = "Straight Line";
		Fit.doFit(fitFunction, PeakArrayX, PeakArrayY);
		a = Fit.p(1);
		b = Fit.p(0);
		if (a==0) return arrayX[itemp];	// !!!!!
		TempsAuPRCTGrelaxVoulu = (YauPRCTGvoulu-b)/a;
		if (Debug) {
			print("TpsYvoulu = "+ TempsAuPRCTGrelaxVoulu);
			print("Droite: " + a +" x + " + b);
		}
		return TempsAuPRCTGrelaxVoulu;
	} 
	return arrayX[itemp];
}

function CalcDerivative(arrayX, arrayY, returnArray, plot) { 
	LongueurArrayY = lengthOf(arrayY);
	if (lengthOf(arrayX) == LongueurArrayY) {
		for (i=1; i<LongueurArrayY; i++) 
			returnArray[i-1] = (arrayY[i]-arrayY[i-1])/(arrayX[i]-arrayX[i-1]);
	} else 
		for (i=1; i<LongueurArrayY; i++) 
			returnArray[i-1] = (arrayY[i]-arrayY[i-1]);
	if(plot){
		txtVunit = " ("+strVunit+") "; txtHunit = " ("+strHunit+") ";
		Plot.create("Derivative", strHaxis +" "+ txtHunit, strVaxis +" "+ txtVunit, arrayX, returnArray);
		Plot.setLineWidth(2);
		Plot.setColor("blue");
		Plot.show();
	}
	returnArray[LongueurArrayY-1] = 0;
	return returnArray;
}

function findVmax( dArray, start, end, sens) { 
//	print(start+" : " + end); 
	returnVal = newArray(2); // 0=y; 1=x
	arrayTemp = Array.slice(dArray,start,end);
	Array.getStatistics(arrayTemp, minArray, maxArray);
	// if (abs(minArray) > abs(maxArray)) maxArray = minArray;
	 if (sens < 0) maxArray = minArray;
	a=0;	while (arrayTemp[a] != maxArray) { a++; }
	returnVal[0]=maxArray; 	returnVal[1]=start+a;
	return returnVal;
}

function AdjFilter(array, n) { 
	NMax = lengthOf(array);
	arrayFiltered = newArray(NMax);
	arrayFiltered[0] = array[0];
	arrayFiltered[NMax-1] = array[NMax-1];
	for(i=1;i<(NMax-1);i++){
		if (i<n)
			ArraySlice = Array.slice(array,0,2*i);
		else if (i>(NMax-n))
			ArraySlice = Array.slice(array,NMax-1-2*(NMax-1-i),NMax-1);
		else 
			ArraySlice = Array.slice(array,i-n,i+n);
		Array.getStatistics(ArraySlice, min, max, meanArraySlice, stdDev);
		arrayFiltered[i] = meanArraySlice;
	}
/*	if (Debug && BM==0) {
		Plot.create("Filtered signal","X","Y");
		Plot.add("line", arrayX, arrayFiltered);
		Plot.show();
		// Array.show(arrayFiltered);
	} /**/
	return arrayFiltered;
}

function FFTplot() {
	if ( !startsWith(getInfo("window.type"), "Plot"))
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: Selected window doesn't seems to be a plot"
			 +"<ul>"
			 +"<li>tip: Drift Removal works only on <b>plot file</b>"
			 +"</ul>");		
	Plot.getValues(xValues, yValues);
	print(yValues[0]);
	// NMax = lengthOf(yValues);
	fftprofile = Array.fourier(yValues, "Hann");
	print(fftprofile[0]);
	nomW = "FFT Spectrum of "+getTitle();
	Plot.create(nomW, " Spatial Freq. ", " Energy (UA) ");
	// zz = zoom*200;
	// Plot.setLimits(0, fftwin/2-1, 0, zz);
	Plot.add("lines", fftprofile);	
}

function plotFilter() {
	if ( !startsWith(getInfo("window.type"), "Plot"))
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: Selected window doesn't seems to be a plot"
			 +"<ul>"
			 +"<li>tip: Drift Removal works only on <b>plot file</b>"
			 +"</ul>");		
	Dialog.createNonBlocking("Adj filter"); {
		Dialog.addSlider("", 0, 20, 1);
		if (selectionType == 0) 
			Dialog.addCheckbox("Clear outside values", false);
	}
	Dialog.show();
	Nfilter=Dialog.getNumber();
	//récupération des valeurs du plot
	Plot.getValues(xValues, yValues);
	NMax = lengthOf(yValues);
	showProgress(0/4);
	if (selectionType == 0) 
		if (Dialog.getCheckbox() == true) {
			getSelectionBounds(xmin, ymin, width, height);
			ymin += height;
			xmax = xmin + width;
			ymax = ymin - height;
			toScaled(xmin, ymin);
			toScaled(xmax, ymax);
			print("Clear...");
			imin = findIndice(xValues, xmin); 
			if (xmax >xValues[NMax-1])
				imax=NMax-1;
			else imax = findIndice(xValues, xmax); 
			showProgress(1/4);
			for (i=imin;i<imax;i++) {
				if (yValues[i] > ymax) 
					yValues[i]=yValues[i-1];
				if (yValues[i] < ymin) 
					yValues[i]=yValues[i-1];
			}
			showProgress(2/4);
		}
	showProgress(3/4);
	if (Nfilter>0)
		yValues=AdjFilter(yValues,Nfilter);
	showProgress(4/4);
	Plot.replace(0, "line", xValues, yValues)
	
}

function AUC(arrayX,arrayY) {
	auc = 0;
	for(i=0; i<lengthOf(arrayX)-1; i++)
		auc += (calcAireTrapeze(arrayX[i],arrayX[i+1],arrayY[i],arrayY[i+1]));
	return auc;
}

function calcAUC(arrayTemps,arraySL,first,last,base){
	//AUC exprimée en UL.UT
	ArraySliceY = Array.slice(arraySL,first,last);
	ArraySliceX = Array.slice(arrayTemps,first,last);
	//permet de récuperer l'aire du trapeze comprenant le pic;
	airePic =  (ArraySliceX[lengthOf(ArraySliceX)-1]-ArraySliceX[0]) * base;
	return airePic - AUC(ArraySliceX, ArraySliceY);
}

function calcAireTrapeze(xA,xB,yA,yB){
	//aire du plus grand rectangle pouvant etre inscrit dans le trapeze
	aireRectMin = abs(xB-xA) * minOf(yB,yA);
	//aire du petit triangle au dessus du trapeze
	airePetitTriangle = abs(xB-xA) * abs(yB-yA) / 2; 
	return (aireRectMin + airePetitTriangle);
}

//Variation = 1 positive ; 0 ou -1 negative 	(SL or contraction)
function peakDetection(plotID, Variation) { 
//detection et analyse des pics
/* Variables:
arrayX: valeur de temps
arrayY: valeurs de SL
nbPoints: nombre de points defini par l'utilisateur pour l'enregistrement
*/
	NSteps = 15; iStep = 0;
	if (Variation==0) Variation=-1;
	selectImage(plotID);
	Plot.getValues(arrayX, arrayYraw); //récupération des valeurs du plot
	// Detection synchro
	stage=1; if (BM != 1) showProgress(iStep++/NSteps);
	useSynchro = false;
	if (BM == 0) {
		// setBatchMode(true);	
		oldName = "";
		if (isOpen("Results")) {
			oldName = "temp_old_result";
			IJ.renameResults(oldName) ;
		}	
		Plot.showValues();
		headings = split(String.getResultsHeadings,"	");
		if (headings.length >2) {
			//3rd series
			arrayY2 = recupPlotArray("Results", headings[2], false);
			ASfS  = call("ij.Prefs.get", "SPIKY.PeakAna.ASfS",0);
			if (ASfS) {
				if (arrayY2.length == arrayX.length) {
					// arrayY2.getStatistics(arrayY2, min2, max2, mean2, sd2);
					synchroIndices = Array.findMinima(arrayY2, 10);
					synchroIndices = Array.sort(synchroIndices);
					print(""+synchroIndices.length+" synch found");
					if (synchroIndices.length>0)
						if (getBoolean("Found possibly synchros \n Use it ?"))
							useSynchro = true;
				}
				// De-allocate Array
				arrayY2 = 0;
			}
		}
		CloseW("Results"); 
		if (oldName != "") {
			if (getVersion()>="1.52" ) {
				Table.rename(oldName,"Results") ;
			} else rename(oldName);
		}
		// setBatchMode(false);
	}
	
	// Detection sampling
	stage=2; if (BM != 1) showProgress(iStep++/NSteps);
	echant = roundn(1/(arrayX[lengthOf(arrayX)-1] - arrayX[lengthOf(arrayX)-2])*Tprop,0);
	if (!BM || Debug) 
		if (echant > =1000)
			print("Detected sampling: "+ roundn(echant/1000,2) + " kHz");
		else 
			print("Detected sampling: "+ echant + " Hz");
	
	smooth = call("ij.Prefs.get", "SPIKY.PeakAna.smooth",-1);
	if (smooth==-1) {
		if ( echant < 500)
			smooth = roundn(echant/200,0);
		else smooth=3;
	}
	
	// print(smooth);
	if (smooth>=1) {
		arrayY = AdjFilter(arrayYraw,smooth);
		if (!BM || Debug) {
			fco = (1-0.442947)*echant/smooth; 	// cut-off frequency
			fco = roundn(fco/10,0)*10; 
			print("cut-off frequency is approximatively "+ fco + " Hz ("+fromCharCode(0x00B1)+smooth+" pts)");
		}
	} else arrayY = arrayYraw;
	
	// arrayY = Drift_Removal(arrayX, arrayY, true);
	
	// Determination param detection - arrayY et notamment de la SD
	stage=3; if (BM != 1) showProgress(iStep++/NSteps);
	Array.getStatistics(arrayY, PDmin, PDmax, PDmean, PDstdDev);
	if (BM==1) {
		// print("Diff = "+abs(PDmax - PDmin));
		if (abs(PDmax - PDmin) < ampDiff)
			return 0;
	}
	PDpoints = lengthOf(arrayY);
	
	Amp = (PDmax - PDmin)/100;
	if (Debug) print("Amp ="+Amp);
	tolerance = call("ij.Prefs.get", "SPIKY.PeakAna.tolerance",15);
	tolerance *= Amp;
	if (Debug) print("tolerance = "+tolerance);
	//detection de pics de contraction. Sont stockés dans array indicePeaks
	if (Variation<0)
		indicePeaks = Array.findMinima(arrayY, tolerance);
	else indicePeaks = Array.findMaxima(arrayY, tolerance);
	indicePeaks = Array.sort(indicePeaks); //tri obligatoire car recup des pic par ordre d'amplitude dans l'array et pas par ordre chronologique !
	
	// Detection des baselines avant pics
	stage=4; if (BM != 1) showProgress(iStep++/NSteps);
	if (Variation<0)
		baselinesPeaksIndices = Array.findMaxima(arrayY, tolerance);
	else baselinesPeaksIndices = Array.findMinima(arrayY, tolerance);
	baselinesPeaksIndices = Array.sort(baselinesPeaksIndices);
	if (Debug) {
		print("Nb peaks:"+lengthOf(indicePeaks));
		print("Nb baseline:"+lengthOf(baselinesPeaksIndices));
	}
	if (lengthOf(baselinesPeaksIndices) < 2)
		if (BM==0) {
			if (spikyBatchDirectMode) {
				IJ.log("Spiky batch warning: No peak found; sample will be handled by batch macro.");
				return 0;
			}
			exit("<html>"
				+"<h1>Spiky</h1>"
				+" <u>Warning</u>: No peak found !"
				+"<ul>"
				+"<li>tip: Decrease parameter <b>Minimum peak amplitude</b>"
				+"</ul>");	
		} else return 0;
	// on test si la première baseline detectée à un indice de position supérieur a celui du premier pic detecté
	// si c'est pas le cas, on vire le premier pic detecté !	
	while (baselinesPeaksIndices[0]>indicePeaks[0]) 
		indicePeaks = Array.slice(indicePeaks,1);

	//detecter les artefacts, decaler de 3 ms
	if (useSynchro) {
		i=0;
		for (j=0; j<synchroIndices.length-1; j++){
			while (indicePeaks[i] < synchroIndices[j]) { 
				i++;
			}
			start = synchroIndices[j]+roundn(1+ echant*3/1000,0);
			partY = Array.slice(arrayY, start, indicePeaks[i]);
			if (Variation<0)
				Tmin = Array.findMaxima(partY, tolerance);
			else Tmin = Array.findMinima(partY, tolerance);
			if (Tmin.length==0) {
				baselinesPeaksIndices[i] = start;
			} else {
				baselinesPeaksIndices[i] = start + Tmin[0];
			}
		}
	}
	
	//on récupère le bon nb de pics detectés
	stage=5; if (BM != 1) showProgress(iStep++/NSteps);
	npeaks = lengthOf(indicePeaks);
	// Test dernier peak
	if (npeaks == lengthOf(baselinesPeaksIndices))
		if (indicePeaks[npeaks-1] > baselinesPeaksIndices[npeaks-1])
			npeaks = npeaks-1;
		else
			if (npeaks > 2) {
				diffl=baselinesPeaksIndices[npeaks-1]-baselinesPeaksIndices[npeaks-2];
				diffl1=0.90*(baselinesPeaksIndices[npeaks-2]-baselinesPeaksIndices[npeaks-3]);
				if (diffl < diffl1)
					npeaks = npeaks-1;
			}
	if (!BM || Debug) print(npeaks + " peaks found"); // affichage du nombre de pics detectés
	if (npeaks < 1) exit();
	indicePeaks = Array.trim(indicePeaks,npeaks);
	
	// Test nombre moyen de pt entre deux max
	minPt = 1; // lengthOf(arrayX);
	if (lengthOf(indicePeaks) > 1) {
		for(i=0; i < lengthOf(indicePeaks)-1; i++) {
			newPt = indicePeaks[i+1] - indicePeaks[i];
			if ( newPt < minPt) minPt = newPt;
		}
	}
	print("MinPt = "+minPt);
	if (BM != 1)
	{
		print("Mean sampling by peak :" + lengthOf(arrayX) / npeaks);
		print("Min sampling for a peak  :" + minPt);
	}
	if ((BM != 1)) 
		/* if ( minPt < 14) { 
			showMessage("Warning", "<html>"
				+"<h1>Spiky</h1>"
				+" <u>Warning</u>: The sampling interval is too low compare to the detected frequency of peaks, analyse may be anaccurate !"
				+"<ul>"
				+"<li>tip: Use a better sampling interval to acquire signal !!!</b>"
				+"</ul>");
		} */
	baselinesPeaks = newArray(lengthOf(baselinesPeaksIndices));
	for (i=0; i<lengthOf(baselinesPeaksIndices); i++) {
		if (minPt > 14 && baselinesPeaksIndices[i] > 3 && baselinesPeaksIndices[i] < (PDpoints-3)){ //on ne fait le smoothing que s'il y a assez de point autour !
			arrayTemp = Array.slice (arrayY,baselinesPeaksIndices[i]-3,baselinesPeaksIndices[i]+3);
			arrayTemp = Array.sort(arrayTemp);
			arrayTemp = Array.slice(arrayTemp, lengthOf(arrayTemp)-4); //on prend les 4 plus grandes valeurs de l'array
			Array.getStatistics(arrayTemp, tempBLmin, tempBLmax, tempBLmean, tempBLstdDev); 
			//De-allocating
			arrayTemp = 0;
			baselinesPeaks[i] = tempBLmean; //correspond à la BL smoothée
		} else {
			baselinesPeaks[i] = arrayY[baselinesPeaksIndices[i]]; //si pas assez de points pour smoother, on prend la valeur telle qu'elle
		}
	}

/*	if (interpolate) {
		baselinesPeaksIndices
	} /* */
	
	timePeaks = newArray(npeaks);
	PeakArrayX = newArray(5);
	PeakArrayY = newArray(5);
	valuePeaks = newArray(npeaks);
	
	// Detection Values of peaks
	stage=6; if (BM != 1) showProgress(iStep++/NSteps);
	for (i=0; i<npeaks; i++){
		timePeaks[i] = arrayX[indicePeaks[i]];
		if (interpolate) {
			if (indicePeaks[i] > 1 && indicePeaks[i] <(lengthOf(indicePeaks) -2)) 
			{
				for(jj=-2; jj<3; jj++) {
					PeakArrayX[2+jj] = arrayX[indicePeaks[i]+jj];
					PeakArrayY[2+jj] = arrayY[indicePeaks[i]+jj];
				}
				fitFunction = "Gaussian";
				Fit.doFit(fitFunction, PeakArrayX, PeakArrayY);
				if (Fit.rSquared>0.9)
					timePeaks[i] = Fit.p(2);
			}
		}
		valuePeaks[i] = arrayY[indicePeaks[i]];
	}
	
	baselinesPeaksMeansArray = newArray(npeaks);
	ampPeaks = newArray(npeaks);
//	fracShortening = newArray(npeaks);

	// Detection of baseline
	stage=7; if (BM != 1) showProgress(iStep++/NSteps);
	for (i=0; i<npeaks-1; i++) { 
		// identification des baselines des pics (moyenne des BL avant et apres pic) jusqu'à l'avant dernier pic
		//faire vérifier que les baselines sont bien de part et d'autre du pic
		if (baselinesPeaksIndices[i] < indicePeaks[i] && baselinesPeaksIndices[i+1] > indicePeaks[i]){
			meanBLpeak = (baselinesPeaks[i+1]+baselinesPeaks[i])/2;
			baselinesPeaksMeansArray[i] = meanBLpeak;
		} else {
			if (spikyBatchDirectMode)
				exit("Spiky batch direct peak detection failed because baseline points did not bracket peak " + i + ". Manual baseline-determination review is not allowed during batch execution.");
			waitForUser ("erreur de determination des baselines ! Revoir l'algorithme");
		}
		ampPeaks[i] = - Variation * (meanBLpeak - valuePeaks[i]);
		// fracShortening[i] = 100*ampPeaks[i]/meanBLpeak;
	}
	//calcul pour le premier et le dernier pic
	ampPeaks[npeaks-1] = - Variation * (baselinesPeaks[npeaks-1]-valuePeaks[npeaks-1]); // dernier pic -> calcul uniquement en fonction de la valeur de BL avant le pic
	baselinesPeaksMeansArray[npeaks-1] = baselinesPeaks[npeaks-1];
//	fracShortening[npeaks-1] = 100*ampPeaks[npeaks-1]/baselinesPeaks[npeaks-1];

	// PtoP: Peak to Peak
	stage = 8; if (BM != 1) showProgress(iStep++/NSteps);
	PtoP = newArray(npeaks-1);
	if (npeaks>1) {
		for (i=0; i<npeaks-1; i++)
			PtoP[i] = timePeaks[i+1] - timePeaks[i];
		// Test frequency
		Array.getStatistics(PtoP, tempmin, tempmax, mean, tempstdDev); 		
		if (Debug) {
			print("min,max: " + tempmin + "," + tempmax);
			print("mean,sd: " + mean + "," + tempstdDev);
		}
		PtoPsort = Array.copy(PtoP);
		Array.sort(PtoPsort); 
		// Array.print(PtoP);
		n = lengthOf(PtoPsort);
		PkI = PtoPsort[n/2]; // PkI = peak interval
		// detecter un changement de frequence
		if (!BM || Debug) {
			print("Detected frequency: " + d2s(1/(PkI/Tprop),1)+" Hz");
			if (npeaks > 2) {
				ectoPeak = 0;
				for (i=0; i<npeaks-1; i++) 
					if (abs(PtoP[i] - PkI) > PkI/10) 
						ectoPeak++;
				if 	(ectoPeak == 0)
					print("frequency stable");
				else if  (ectoPeak > n/2)
					print("frequency not stable");
				else {
					for (i=0; i<npeaks-1; i++) {
						diff =  PtoP[i] - PkI;
						if (abs(diff) > PkI/10) {
							if (diff < 0) {
								print("Peak " + (i+2) + " is ahead");
								i++;
							} else print("Peak " + (i+2) + " is delayed");
						}
					}
				}
			}
		}
	}

	// Detection of threshold & timetopeak, 
	stage = 9; if (BM != 1) showProgress(iStep++/NSteps);
	// if (call("ij.Prefs.get", "SPIKY.PeakAna.FW",1)) 
	{
		thresholdDetectionDEbPeak = call("ij.Prefs.get", "SPIKY.PeakAna.TTP.thresholdDetectionDEbPeak",5);
		TimeToPeaks = newArray(npeaks);
		ThresholdX = newArray(npeaks);
		ThresholdY = newArray(npeaks);
		for (i=0; i<npeaks; i++) {
			YauPRCTGvoulu = valuePeaks[i] - ( (100-thresholdDetectionDEbPeak) * (valuePeaks[i] - baselinesPeaks[i]) / 100 );
			ThresholdX[i] = TTxPeaki(arrayY, indicePeaks[i], YauPRCTGvoulu, -1);
			ThresholdY[i] = arrayY[ThresholdX[i]];
			ThresholdX[i] =arrayX[ThresholdX[i]];
			TimeToPeaks[i] = abs( ThresholdX[i] - timePeaks[i]);
		} /* */
	}
	
	// Detection of FW/HW
	stage = 10; if (BM != 1) showProgress(iStep++/NSteps);
	if (call("ij.Prefs.get", "SPIKY.PeakAna.FW",1) || call("ij.Prefs.get", "SPIKY.PeakAna.HW",1)) { 
		x1P = 1* call("ij.Prefs.get", "SPIKY.PeakAna.x1P",20);
		x2P = 1*call("ij.Prefs.get", "SPIKY.PeakAna.x2P",80);
	
		// Detection of RW
		RWx1 = newArray(npeaks);
		for (i=0; i<npeaks; i++)
				RWx1[i] = TTxPeak(arrayX,arrayY,indicePeaks[i], valuePeaks[i] - baselinesPeaks[i+1], valuePeaks[i], x1P, 1) - timePeaks[i];
		RWx2 = newArray(npeaks);
		for (i=0; i<npeaks; i++)
			RWx2[i] = TTxPeak(arrayX,arrayY,indicePeaks[i],valuePeaks[i] - baselinesPeaks[i+1], valuePeaks[i], x2P, 1)- timePeaks[i];
	
		// Detection of LW
		LWx1 = newArray(npeaks);
		for (i=0; i<npeaks; i++) {
			LWx1[i] = timePeaks[i] - TTxPeak(arrayX,arrayY,indicePeaks[i],valuePeaks[i] - baselinesPeaks[i], valuePeaks[i], x1P, -1);
		}
		LWx2 = newArray(npeaks);
		for (i=0; i<npeaks; i++) {
			LWx2[i] = timePeaks[i] - TTxPeak(arrayX,arrayY,indicePeaks[i],valuePeaks[i] - baselinesPeaks[i], valuePeaks[i], x2P, -1);
		}
		// Detection of FWHM
		RW50 = newArray(npeaks);
		for (i=0; i<npeaks; i++) {
			RW50[i] = TTxPeak(arrayX,arrayY,indicePeaks[i],valuePeaks[i] - baselinesPeaks[i+1], valuePeaks[i], 50, 1) - timePeaks[i];
		}
		LW50 = newArray(npeaks);
		for (i=0; i<npeaks; i++) {
			LW50[i] = timePeaks[i] - TTxPeak(arrayX,arrayY,indicePeaks[i],valuePeaks[i] - baselinesPeaks[i], valuePeaks[i], 50, -1);
		}
	}

	// Detection of Vmax 
	stage = 11; if (BM != 1) showProgress(iStep++/NSteps);
	if (call("ij.Prefs.get", "SPIKY.PeakAna.Vmax",1)) {
		derivArray = newArray(lengthOf(arrayY));
		Dplot=call("ij.Prefs.get", "SPIKY.PeakAna.DerivativeSig",0);
		if (minPt < 14)
			CalcDerivative(arrayX, arrayY, derivArray, Dplot);
		else 	
		{
			adjN = minOf(minPt/10 , 100);
			CalcDerivative(arrayX, AdjFilter(arrayY, adjN), derivArray, Dplot);
		}
		if (Dplot) setBatchMode("show");
		VmaxCont = newArray(npeaks);
		VmaxRel = newArray(npeaks);
		VmaxContTime = newArray(npeaks);
		VmaxRelTime = newArray(npeaks);
		
		for (i=0; i<npeaks; i++) { //contraction max
			tab = findVmax( derivArray, baselinesPeaksIndices[i], indicePeaks[i], Variation);
			VmaxCont[i] = tab[0];		// valeur Y
			VmaxContTime[i] = tab[1];  // indice
		}
		for (i=0; i<(npeaks); i++) { //relaxation max
		// for (i=0; i<(npeaks-1); i++) { //relaxation max
			tab = findVmax( derivArray, indicePeaks[i], baselinesPeaksIndices[i+1], -Variation);
			VmaxRel[i] = tab[0];
			VmaxRelTime[i] = tab[1];
		}
		derivArray = 0;
	}
	
	// Detection of AUP
	stage = 12; if (BM != 1) showProgress(iStep++/NSteps);
	if (call("ij.Prefs.get", "SPIKY.PeakAna.AUP",1)) {
		AUP = newArray(npeaks);
		AUPc = newArray(npeaks);
		AUPr = newArray(npeaks);
		for (i=0; i<npeaks; i++) {
		//valeurs & vérifier
			base = (arrayY[baselinesPeaksIndices[i]] + arrayY[baselinesPeaksIndices[i+1]])/2;
			// AUP[i] = calcAUC(arrayX,arrayY,baselinesPeaksIndices[i],baselinesPeaksIndices[i+1], base);
			AUPc[i] = -Variation * calcAUC(arrayX,arrayY,baselinesPeaksIndices[i],indicePeaks[i],base);
			AUPr[i] = -Variation * calcAUC(arrayX,arrayY,indicePeaks[i],baselinesPeaksIndices[i+1],base);
			AUP[i] = AUPc[i] + AUPr[i];
		}
	}
	
	// Detection of decay
	stage = 13; showProgress(iStep++/NSteps);
	if (call("ij.Prefs.get", "SPIKY.PeakAna.decay",0)) {
		pdecay = call("ij.Prefs.get", "SPIKY.PeakAna.pdecay",66);
// if (BM == 0) setBatchMode(true);	
		decay = newArray(npeaks);
		for (i=0; i<npeaks; i++) {
			base = (arrayY[baselinesPeaksIndices[i]] + arrayY[baselinesPeaksIndices[i+1]])/2;
			imax = baselinesPeaksIndices[i+1] ;
			imin = indicePeaks[i];
			// YauPRCTGvoulu = valuePeaks[i] + ( (100-pdecay) * (valuePeaks[i] - baselinesPeaks[i+1]) / 100 ); //vérifier sens du signal
			YauPRCTGvoulu = valuePeaks[i] - ( (100-pdecay) * (valuePeaks[i] - baselinesPeaks[i+1]) / 100 );
			imin = TTxPeaki(arrayY,  indicePeaks[i], YauPRCTGvoulu, 1);
			print("--- FIT ---");
			print(YauPRCTGvoulu);
			print("de "+imin+" à " + imax);
			X = newArray(imax-imin+1);
			Y = newArray(imax-imin+1);

			// array.slice
			val0 = arrayX[imin];
			for (ii = imin;ii <= imax;ii++) {
				X[ii-imin] = arrayX[ii]-val0;
				Y[ii-imin] = arrayY[ii];
			}
			// setBatchMode("hide");
			fitFunction = "Exponential with Offset";
			Fit.doFit(fitFunction, X, Y);
			Fit.plot();
			print("val["+i+"] = " + (Fit.p(0)));
			print("tau["+i+"] = " + (Fit.p(1)));
			
			decay[i] = 1/Fit.p(1);
			// setBatchMode("show");	
			run("Close");
		}
// if (BM == 0) setBatchMode(false);
	}
	
	// Creation du graph
	stage = 14;if (BM != 1) showProgress(iStep++/NSteps);
	if (call("ij.Prefs.get", "SPIKY.PeakAna.SPWHDP",1)) { //identification des pics sur le graph
		Plot.create(srcName+"-detected_peaks", strHaxis + txtHunit, strVaxis + txtVunit); //,time, SL);
			Plot.setLineWidth(1);
			Plot.setColor("black");
			if (call("ij.Prefs.get", "SPIKY.PeakAna.SSSL",1))
				Plot.add("line", arrayX, arrayY);
			else Plot.add("line", arrayX, arrayYraw);
			
			Plot.setColor("red");
			Plot.setLineWidth(3);
			Plot.add("triangles",timePeaks,valuePeaks);
			
			Plot.setColor("green");
			Plot.setLineWidth(3);
			Xval = newArray(npeaks);
			Yval = newArray(npeaks);
			if (call("ij.Prefs.get", "SPIKY.PeakAna.Dthreshold",1)) {
				for (i=0; i<npeaks; i++){
					Xval[i] = ThresholdX[i];
					Yval[i] = ThresholdY[i];
				}
				Plot.add("circles",Xval,Yval);
			} 
			if (call("ij.Prefs.get", "SPIKY.PeakAna.Vmax",1))
				if (call("ij.Prefs.get", "SPIKY.PeakAna.DVmax",0)) {
					Plot.setColor("magenta");
					for (i=0; i<lengthOf(VmaxContTime); i++){
						Xval[i] = (arrayX[VmaxContTime[i]] + arrayX[VmaxContTime[i]+1])/2;
						Yval[i] = (arrayY[VmaxContTime[i]] + arrayY[VmaxContTime[i]+1])/2;
					}
					Plot.add("circles",Xval, Yval);
					Plot.setColor("magenta");
					for (i=0; i<lengthOf(VmaxRelTime); i++){
						Xval[i] = (arrayX[VmaxRelTime[i]] + arrayX[VmaxRelTime[i]+1])/2;
						Yval[i] = (arrayY[VmaxRelTime[i]] + arrayY[VmaxRelTime[i]+1])/2;
					}
					Plot.add("circles",Xval, Yval);
				}			
			if (call("ij.Prefs.get", "SPIKY.PeakAna.Dbaseline",1)) {
				Xval = newArray(lengthOf(baselinesPeaksIndices));
				Plot.setColor("blue");
				for (i=0; i<lengthOf(baselinesPeaksIndices); i++){
					Xval[i] = arrayX[baselinesPeaksIndices[i]];
				}
				Plot.add("circles",Xval, baselinesPeaks);				
			}
			Plot.setLineWidth(1);
		Plot.show();
		setBatchMode("show");
	}
	
	// Create table
	stage = 15;if (BM != 1) showProgress(iStep++/NSteps);
	if (call("ij.Prefs.get", "SPIKY.PeakAna.ShowSumTable",1)) {
		if (isOpen("Results")) 
			if (!getBoolean("Overwrite old \"Results \" ?"))
				exit();
		Array.show("Results");
		// Array.show("Results(indexes)");
		decimal = call("ij.Prefs.get", "SPIKY.PeakAna.decimal",6);
		run("Set Measurements...", "  decimal="+decimal);
		setOption("ShowRowNumbers", false);
		for (i=0;i<npeaks;i++) {
			setResult("Index", i, i+1);
			setResult("Pos", i, indicePeaks[i]);
			setResult("Tmax" + txtHunit, i, timePeaks[i]);
			setResult("APeak"+txtVunit, i, valuePeaks[i]);
			setResult("Baseline Bl"+txtVunit, i, baselinesPeaksMeansArray[i]);
			setResult("Amplitude"+txtVunit, i, ampPeaks[i]);
//			setResult("Pk2Bl (%)", i, fracShortening[i]);
		}
		
		setResult("Pk2Pk" + txtHunit, 0, "NA");
		
		if (npeaks>1) {
			for (i=0;i<npeaks-1;i++) 
				setResult("Pk2Pk" + txtHunit, i+1, PtoP[i]);
		}
		for (i=0;i<npeaks;i++) 
			setResult("Time2Pk" + txtHunit, i, TimeToPeaks[i]);
		
		if (call("ij.Prefs.get", "SPIKY.PeakAna.FW",1)) {
			for (i=0;i<npeaks;i++) {
				setResult("FWHM" + txtHunit, i, LW50[i]+RW50[i]);
				setResult("FW"+x1P + txtHunit, i, LWx1[i]+RWx1[i]);
				setResult("FW"+x2P + txtHunit, i, LWx2[i]+RWx2[i]);
			}
		}
		if (call("ij.Prefs.get", "SPIKY.PeakAna.HW",1)) {
			for (i=0;i<npeaks;i++) {
				setResult("LW50" + txtHunit, i, LW50[i]);
				setResult("LW"+x1P + txtHunit, i, LWx1[i]);
				setResult("LW"+x2P + txtHunit, i, LWx2[i]);
				setResult("RW50" + txtHunit, i, RW50[i]);
				setResult("RW"+x1P + txtHunit, i, RWx1[i]);
				setResult("RW"+x2P + txtHunit, i, RWx2[i]);
			}
		}
		if (call("ij.Prefs.get", "SPIKY.PeakAna.Vmax",1)) {
			for (i=0;i<npeaks;i++) {
				setResult("SlopeMax2Pk ("+strVunit+"/"+strHunit+")", i, VmaxCont[i]);
				setResult("SlopeMax2Bl ("+strVunit+"/"+strHunit+")", i, VmaxRel[i]);
			}
			//De-allocating
			//VmaxCont=0; VmaxRel=0; //VmaxContTime=0; VmaxRelTime=0;
		}
		if (call("ij.Prefs.get", "SPIKY.PeakAna.AUP",1)) {			
			for (i=0;i<npeaks;i++) {
				setResult("PkArea ("+strVunit+"."+strHunit+")", i, AUP[i]);
				setResult("AreaBl2Pk ("+strVunit+"."+strHunit+")", i, AUPc[i]);
				setResult("AreaPk2Bl ("+strVunit+"."+strHunit+")", i, AUPr[i]);
			}
			//De-allocating
			AUP=0; AUPc=0;AUPr=0;
		}
		if (call("ij.Prefs.get", "SPIKY.PeakAna.decay", 0))  {
			for (i=0;i<npeaks;i++) {
				setResult("tau decay" + txtHunit, i, decay[i]);
			}
		}		
		
		updateResults();		
		if (call("ij.Prefs.get", "SPIKY.PeakAna.summarize",0))
			run("Summarize");
		IJ.renameResults(srcName+"-Peak analysis");
	}
	else if (BM==1) {
		TstartMoy = 0; PosMoy = 0;FWHMMoy = 0;AmplitudeMoy = 0; 
		decayMoy = 0; dvdtMoy = 0;
		isDecay = call("ij.Prefs.get", "SPIKY.PeakAna.decay", 0);
		isdvdt = call("ij.Prefs.get", "SPIKY.PeakAna.Vmax", 0);
		for (i=0;i<npeaks;i++) {
			FWHMMoy += RW50[i]+LW50[i];
			PosMoy += indicePeaks[i];
			TstartMoy += timePeaks[i];
			AmplitudeMoy += ampPeaks[i];
			APD90Moy += RWx2[i];
			if (isdvdt)
				dvdtMoy += VmaxCont[i];
			if (isDecay)
				decayMoy += decay[i];
		}
		valMoy[0] = FWHMMoy / npeaks;
		valMoy[1] = AmplitudeMoy / npeaks;
		valMoy[2] = TstartMoy / npeaks;
		valMoy[3] = APD90Moy / npeaks;
		if (isdvdt)
			valMoy[4] = dvdtMoy / npeaks;
		if (isDecay)
			valMoy[5] = decayMoy / npeaks;
		CloseW(srcName+"-detected_peaks");
		return 1;
	}
	//De-allocating
		arrayX=0; arrayYraw=0;
	
	return 1;
}

//Variation = -1 auto ; 1 positive ; 0 negative 	(SL or contraction)
function launchAnalysis(Variation) {
	requires("1.51s");
	srcName = "";
	FI = 0;
	if ( !startsWith(getInfo("window.type"), "Plot"))
		plotResult();
	if (srcName == "") srcName = getInfo("window.title");
	plotid = getImageID();
	IJ.log("Starting analysis...");
	
	
	Plot.getValues(X, Ztab); //récupération des valeurs du plot
	// test validité de l'axe des X
	// test les 100 premieres valeurs pour verifiez qu'il n'y ait pas de valeurs identiques
	error=false;
	MaxN=minOf(300,X.length)-2;
	print(MaxN);
	for (i=0; i< MaxN; i++)
		if (X[i+1] == X[i]) {
			// could be fixed
			error=true;
			break;
		}
		if (X[i+1] < X[i]) {
			// doesnt fix this
			exit("<html>"
				 +"<h1>Spiky</h1>"
				 +"<u>Error</u>: There is an error with X values that couldn't be fixed automatically!"
				 +"<ul>"
				 +"<li>tip: Check your data !"
				 +"</ul>");
		}			
	if (error==true) {
		if (spikyBatchDirectMode)
			exit("<html>"
				 +"<h1>Spiky</h1>"
				 +"<u>Error</u>: There is an error with X values and direct batch execution cannot use the manual X-axis repair dialog."
				 +"<ul>"
				 +"<li>tip: Check your data !"
				 +"</ul>");
		Dialog.create("Error"); {
			Dialog.addMessage("There is an error with X values, trying to fix ? \nBe careful, this fix isn't sure, Check your data !");
			Dialog.show();
			// noZero = Dialog.getCheckbox();
		}			
		print("Trying to fix...");
		X=AdjFilter(X, 1);
		Plot.replace(0, "line", X, Ztab);
	}
	
	// detect auto sens de l'analyse
	if (Variation == -1) {
		// Ztab = GetZprofile(2, nSlices);
		Array.sort(Ztab); 
		Q1=Ztab[frames/4];
		Q2=Ztab[frames/2];
		Q3=Ztab[frames*3/4];
		// Array.getStatistics(Ztab, Zmin, Zmax, Zmean, ZstdDev);
		// print("Image:mean="+Zmean+" max="+Zmax+" min="+Zmin+" sd="+ZstdDev);		
		// if ((Zmax - Zmean) < (Zmean-Zmin))
		if (abs(Q1-Q2) > abs(Q2-Q3))
			Variation = 0; //neg
		else Variation = 1; //pos
		if (Variation)
			IJ.log("Automatic detection: Positive");
		else IJ.log("Automatic detection: Negative");
		autoDetect = call("ij.Prefs.get", "SPIKY.PeakAna.autoDetect","Automatic");
		if (autoDetect!="Automatic" && !spikyBatchDirectMode) {
			Dialog.create("Parameters"); {
				sens = newArray("negative","positive");
				Dialog.addChoice("Sens of analysis", sens, sens[Variation]);
				Dialog.addMessage(sCop);
				Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky");
				Dialog.show();
				if (startsWith(Dialog.getChoice(),sens[0]))
					Variation = 0;
				else Variation = 1;
			}
		}
		//De-allocating
		X=0; Ztab=0;
	}
	
	selectImage(plotid);
	if (BM==0)
		if (getVersion()>"1.51s" ) {
			eval("script","IJ.selectWindow("+plotid+")");  // remplace selectImage
			Vaxis = eval("script","WindowManager.getActiveWindow().getPlot().getLabel('y')");
			strVaxis = extractLabel(Vaxis,"l");
			strVunit = extractLabel(Vaxis,"u");
			if (Debug) {
				IJ.log("Y label: " + strVaxis);
				IJ.log("Y unit: " + strVunit);
			}
		}
	detectXunitfromPlot(plotid);
	
	IJ.log("found X values:" + strHaxis + " in " + strHunit);
	if (spikyBatchDirectMode && lengthOf(strVaxis)>0)
		IJ.log("Spiky batch direct source plot Y axis accepted; label=" + strVaxis + "; unit=" + strVunit);
	if (lengthOf(strVunit)<1 && !(spikyBatchDirectMode && lengthOf(strVaxis)>0)) {
		Dialog.create("Analysis setup"); {
			Dialog.addString("Vertical axis label", strVaxis, 20); 
			Dialog.addString("Vertical axis unit", strVunit, 3);
			Dialog.addMessage("Note: Time MUST be in seconds !!!");
			Dialog.addMessage(sCop);
			Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky");
			Dialog.show();
			strVaxis = Dialog.getString();
			strVunit = Dialog.getString();
		}
		if (Variation == 1) {
			call("ij.Prefs.set", "SPIKY.PeakAna.strVaxisP",strVaxis);
			call("ij.Prefs.set", "SPIKY.PeakAna.strVunitP",strVunit);
		} else {
			call("ij.Prefs.set", "SPIKY.PeakAna.strVaxisN",strVaxis);
			call("ij.Prefs.set", "SPIKY.PeakAna.strVunitN",strVunit);
		}		
	}

	selectImage(plotid);
	if (selectionType == 0) {
		ZoomToRoi();
	}
	plotid = getImageID();
	if (lengthOf(strVunit)<1 && spikyBatchDirectMode && lengthOf(strVaxis)>0)
		txtVunit = "";
	else
		txtVunit = " ("+strVunit+") ";
	txtHunit = " ("+strHunit+") ";
	//parameters: videoid, Variation (Variation d'analyse positif ou negatif => SL ou contraction)
	setBatchMode(true);
	IJ.log("found Y values:" + strVaxis + " in " + strVunit);
	retour = peakDetection(plotid,Variation);
	setBatchMode(false);
	
	// wait(100); call("java.lang.System.gc");
	return retour;
}

/********************** ISOCHRONE MAP *************************/
function Measure() {
	init_Common_values();
	is_Calibrated = false;
	if (bitDepth() == 32) {
		Tunits = getTag("Calibration unit:");
		if ( lengthOf(Tunits)==0 )
			if ( lengthOf(getTag("Calibration"))>0 ) {
				Tunits = getTag(" Unit:");
				Tunits = substring(Tunits, indexOf(Tunits,"\"")+1, lastIndexOf(Tunits,"\""));
			}
		if ( lengthOf(Tunits)>0 ) {
			// print("Debug: Tunits="+Tunits);
			prop = calibrateTime(Tunits);
			// print("prop="+prop);
			factor =  1;
			if (prop != 0)
				is_Calibrated = true;
		}	
	} else if ( lengthOf(getTag("Calibration")) >0 ) {
		factor =  1/parseFloat(getTag("b:"));
		is_Calibrated = true;
		// print("Image is calibrated");
		Tunits = getTag("Unit");
		Tunits = substring(Tunits, indexOf(Tunits,"\"")+1, lastIndexOf(Tunits,"\""));
		// print("Tunits="+Tunits);
		prop = calibrateTime(Tunits);
		// print("prop="+prop);
		// print("factor="+factor);
	} 
	if (is_Calibrated) {		
		makeLine(xx1, yy1, xx1+10, yy1+10);
		statusStr="out of bounds";
		PstartOld=0; PendOld=0;
		while(1) {
			type = selectionType();
			if (type != 5) return;
			getSelectionCoordinates(x, y);
			Pstart = getPixel(x[0], y[0]);
			Pend = getPixel(x[1], y[1]);
			if (!(PstartOld==Pstart && PendOld==Pend)) {
				if (Pstart==0 || Pend==0) statusStr="out of bounds";
				else {
					dx = (x[1] - x[0])*pixelW;
					dy = (y[1] - y[0])*pixelH;
					distance = sqrt(dx*dx + dy*dy);
					time = abs(Pstart - Pend);
					statusStr=""+ distance / time +" "+unit+"/"+Tunits;
				}
				PstartOld=Pstart; PendOld=Pend;
			}
			wait(1);
			showStatus(statusStr);
		}
	} else 		
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: Pixel isn't calibrated!"
			 +"<ul>"
			 +"<li>tip: Measure speed need a calibrated image. Use <b>Analyse/Calibrate</b>"
			 +"</ul>");
}

function AutoAdjust(is_32) {
	getRawStatistics(Hcount, Hmean, Hmin, Hmax, Hstd, Histogram); 
	imax=1; //Debug=true;
	for (i=1; i<lengthOf(Histogram); i++) 
		if (Histogram[i] > Histogram[imax])
			imax = i;
	if (Debug) 
	{
		print("AutoAdjust:");
		print("=========");
		print("length:"+lengthOf(Histogram));
		print("Count:"+Hcount);
		print("Hmean:"+Hmean);
		print("Hmin:"+Hmin);
		print("Hmax:"+Hmax);
		
		print("imax:"+imax);
		print("val[imax]:"+Histogram[imax]);
		
		Array.show(Histogram);
	}
//	if (Hmin < 0) Hmin = 0;
//	if (is_32) Hmin = 5;

	if (is_32) {
		lim = Histogram[imax]/5;
		Tmin = 1;
		Tmax = lengthOf(Histogram)-1;
		if (Hmax<0 )
			pas = -(Hmax + Hmin)/lengthOf(Histogram);
		else 
			pas = (Hmax - Hmin)/lengthOf(Histogram);
		
		if (Debug)  print("pas: "+pas);
		for (i=imax; i>1; i--) 
			if (Histogram[i] != 0)
				if (Histogram[i] < lim ) {
					Tmin = i;
					break;
				} 
		if (Debug)  print("Tmin: "+ Tmin);
		for (i=imax; i<lengthOf(Histogram); i++)
			if (Histogram[i] != 0)			
				if (Histogram[i] < lim ) {
					Tmax = i;
					break;
				} /**/
		if (Debug)  print("Tmax: "+ Tmax);
		Hmax = Hmin+Tmax*pas;
		Hmin = Hmin+Tmin*pas;
	} else {
		lim = Hcount/1000;
		for (i=1; i<250; i++) 
			if (Histogram[i] > lim ) {
				Hmin = i;
				break;
			} 
		for (i=255; i>0; i--) 
			if (Histogram[i] > lim ) {
				Hmax = i;
				break;
			}  
	}
	//De-allocating
	Histogram = 0;
	if (Debug) 
	{
		print("Min is "+Hmin);
		print("Max is "+Hmax);
	}
	setMinAndMax(Hmin-1, Hmax);
} 

function autoFill() {
	ret = findNextPeak();
	if (slices==1) {
		if (frame == frames) frame = 1;
		start = frame + 1;
		end = frames;
	} else {
		if (slice == slices)	slice = 1;
		start = slice + 1;
		end = slices;
	}
	if (ret[0] == -1)  return "no Min found";
	if (ret[0] <= 0) return "Found no peaks";
	if (ret[2] == 0) return "no second min";
	call("ij.Prefs.set", "MAPPING.sliceIni",toString(ret[1]));
	call("ij.Prefs.set", "MAPPING.sliceEnd",toString(ret[2]));
	return "limits: "+ret[1]+"-"+ret[2];
	// Array.print(ret);
}

function Isochrone_map() {
	Isochrone_map_start(false);
}

function Isochrone_map_start(auto) {
	//  requires("1.52q");
	ver = getVersion();
	// select last image/stack => avoid Log/dialog windows.
	selectImage(getImageID());
	Winfo=getInfo("window.type");
	if ( !startsWith(Winfo, "Image")) {
		if (lengthOf(Winfo) > 0)
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: selected windows isn't correct"
			 +"<ul>"
			 +"<li>tip: Use a <b>Z-stack images</b> or select a <b>Result table</b>"
			 +"</ul>");
		else
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: There are no images open"
			 +"<ul>"
			 +"<li>tip: Open a <b>Z-stack images</b> or select a <b>Result table</b>"
			 +"</ul>");
	}
	
	if (ver < "1.52q") 
		showMessageWithCancel("Informations","This function will be best working with ImageJ version 1.52q or superior.\n If you continue, you will need to manually calibrate the pixelvalue unit.");
	
	init_XYT_values();
	
	tolerancePerCent = call("ij.Prefs.get", "SPIKY.PeakAna.tolerance",15);
	isSel = selectionType();
	//recurrence; colortoframe; S-Golay
	Nrec = 1; cFrame=1; is_SG=false; SG_DO=0; method = "";

	// detect sens de l'analyse
	Ztab = GetZprofile(2, nSlices);
	Array.getStatistics(Ztab, Zmin, Zmax, Zmean, ZstdDev);
	print("Image:mean="+Zmean+" max="+Zmax+" min="+Zmin+" sd="+ZstdDev);		
	if ((Zmax - Zmean) < (Zmean-Zmin))
		sensAna = 0; //neg
	else sensAna = 1; //pos
	
	// load default
		sensit = parseFloat(call("ij.Prefs.get", "MAPPING.sensit","5"));
		binax = parseFloat(call("ij.Prefs.get", "MAPPING.binax","1"));
		bintemp = parseFloat(call("ij.Prefs.get", "MAPPING.bintemp","1"));
		//bintype = call("ij.Prefs.get", "MAPPING.bintype","Average");
		bintype = "Average";
		interpolate = parseFloat(call("ij.Prefs.get", "MAPPING.interpolate","0"));
		sliceIni = parseFloat(call("ij.Prefs.get", "MAPPING.sliceIni","1"));
		if (sliceIni>(nSlices/channels)) sliceIni = 1;
		sliceEnd = parseFloat(call("ij.Prefs.get", "MAPPING.sliceEnd",(nSlices/channels)));
		if (sliceEnd>(nSlices/channels)) sliceEnd = nSlices/channels;			
		
		smooth = call("ij.Prefs.get", "MAPPING.smooth","Median");
		method = call("ij.Prefs.get", "MAPPING.method","Threshold");
		PostP = parseFloat(call("ij.Prefs.get", "MAPPING.PostP","1"));
		overlay = call("ij.Prefs.get", "MAPPING.overlay","Ask");
		
		SG_HWS = parseFloat(call("ij.Prefs.get", "MAPPING.SG_HWS","3"));
		SG_PO = parseFloat(call("ij.Prefs.get", "MAPPING.SG_PO","0"));
		SG_DO = parseFloat(call("ij.Prefs.get", "MAPPING.SG_DO","0"));
		SG_KO = parseFloat(call("ij.Prefs.get", "MAPPING.SG_KO","0"));
		cFrame = parseFloat(call("ij.Prefs.get", "MAPPING.cFrame","1"));
		title="Mapping";
		if (!isSGolay) {
			items2 = newArray("None","Smooth","Despeckle","Median...");
		} else {
			items2 = newArray("None","Smooth","Despeckle","Median...","Savitzky Golay");
		}
		Tmethod = newArray("Peak", "Slope", "Threshold");
		items3 = newArray("Never","Always","Ask");
		is_Hist=false;
	if (auto == false) {
		Dialog.create(title);
		Dialog.addString("Analysis Suffix", "map", 15) ;
		
		sens = newArray("negative","positive");
		Dialog.addChoice("Sens of analysis", sens, sens[sensAna]);

		Dialog.addChoice("Method", Tmethod, method);
		
		if (isSel != -1)
			Dialog.addCheckbox("Use Selection", true);
		if(slices>1)
			Dialog.addMessage("Voxel size is (xyz): "+pixelW+" - "+pixelH+" - "+pixelD+" "+unit);
		else if(frames>1)
			Dialog.addMessage("Voxel size is (xyt): "+pixelW+" - "+pixelH+" "+unit+" - "+FI +" "+Tunits);
		Dialog.addNumber("Binning : Axial  (x"+fromCharCode(0x00B1)+")", binax);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addNumber("Temporal (x"+fromCharCode(0x00B1)+")", bintemp);
		Dialog.addNumber("Sensitivity (mid = 5) ", sensit);
		Dialog.addMessage("Remark: Sensitivity may be deactivated using value 0.\nThis may be usefull if there is no background in your selection.");	
		Dialog.addMessage("Pre-processing:");	
		Dialog.addChoice("Smoothing...", items2, smooth);
		if (!isSGolay) 
			Dialog.addMessage("Savitzky-Golay 3D filter not found, (see 'Log window' )");
		Dialog.addCheckbox("Post-processing ", PostP);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addCheckbox("Interpolate", interpolate);
		Dialog.addChoice("Paste overlay...", items3, overlay);
		Dialog.addMessage("Analysis time zone");
		Dialog.addNumber("first slice", sliceIni);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		Dialog.addNumber("last slice", sliceEnd);
		Dialog.addNumber("Recurrence", Nrec);
		Dialog.addCheckbox("Set color to frame.", cFrame);
		if (ver >= "1.52f") Dialog.addToSameRow(); 
		// Dialog.addCheckboxGroup(rows, columns, labels, defaults);
		Dialog.addCheckbox("Display Histogram", is_Hist);
		Dialog.addMessage(sCop);
		Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky/isochronalMap.html");
		Dialog.show();
		title = Dialog.getString();
		
		if (startsWith(Dialog.getChoice(),sens[0]))
			sensAna = 0;
		else sensAna = 1;	
		method = Dialog.getChoice();			
		if (isSel != -1)
			if (!Dialog.getCheckbox()) {
				run("Select None");
				isSel = selectionType();
			}
		binax = Dialog.getNumber();
		bintemp = Dialog.getNumber();
		smooth = Dialog.getChoice();
		PostP  = Dialog.getCheckbox();
		sensit = Dialog.getNumber();
//		if (sensit<1) sensit = 1;
		overlay = Dialog.getChoice();
		interpolate = Dialog.getCheckbox();
		sliceIni = Dialog.getNumber();
		sliceEnd = Dialog.getNumber();
		Nrec = Dialog.getNumber();
		cFrame = Dialog.getCheckbox();
		is_Hist = Dialog.getCheckbox();
		
		call("ij.Prefs.set", "MAPPING.sensit",toString(sensit));
		call("ij.Prefs.set", "MAPPING.binax",toString(binax));
		if (Debug) print("binax = " + binax);
		call("ij.Prefs.set", "MAPPING.bintemp",toString(bintemp));
		if (Debug) print("bintemp = " + bintemp);
		call("ij.Prefs.set", "MAPPING.interpolate",toString(interpolate));
		call("ij.Prefs.set", "MAPPING.sliceIni",toString(sliceIni));
		call("ij.Prefs.set", "MAPPING.sliceEnd",toString(sliceEnd));
		call("ij.Prefs.set", "MAPPING.smooth",smooth);
		call("ij.Prefs.set", "MAPPING.overlay",overlay);
		call("ij.Prefs.set", "MAPPING.PostP",toString(PostP));
		call("ij.Prefs.set", "MAPPING.method",method);
		call("ij.Prefs.set", "MAPPING.cFrame",toString(cFrame));
		
		if (Debug) print("Smooth = " + smooth);
		if (smooth == "Savitzky Golay")
		{
//			smooth = items2[0];
			is_SG = true;
	
			Dialog.create("Options"); {
				Dialog.addMessage("Savitzky-Golay filter");
				Dialog.addNumber("half-window size (pix)", SG_HWS);
				Dialog.addNumber("Polynomial order", SG_PO);
				Dialog.addNumber("Derivative order", SG_DO);
				Dialog.addCheckbox("keep open SG-filtered image", SG_KO);
				Dialog.show();
				
				SG_HWS = Dialog.getNumber();
				SG_PO = Dialog.getNumber();
				SG_DO = Dialog.getNumber();
				SG_KO = Dialog.getCheckbox();
			}
			call("ij.Prefs.set", "MAPPING.SG_HWS",toString(SG_HWS));	
			call("ij.Prefs.set", "MAPPING.SG_PO",toString(SG_PO));
			call("ij.Prefs.set", "MAPPING.SG_DO",toString(SG_DO));
			call("ij.Prefs.set", "MAPPING.SG_KO",toString(SG_KO));
		}
	} 
		
	if (sliceEnd>nSlices)
		exit("<html>"
			 +"<h1>sVer</h1>"
			 +"<u>Warning</u>: Array index  out of bounds"
			 +"<ul>"
			 +"<li>tip: Change settings"
			 +"</ul>");
			 
	// calcul nb ttal d'images:
	nbImages = sliceEnd-sliceIni+1;
	if (Nrec>1) {
		if ((nbImages*Nrec)>(nSlices-sliceIni))
			exit("<html>"
				 +"<h1>sVer</h1>"
				 +"<u>Warning</u>: cannot use recurrence"
				 +"<ul>"
				 +"<li>tip: Uncheck it"
				 +"</ul>");
	}
	
	selectWindow(nom_ori);
	zoom = getZoom();
	for(nrec=1; nrec<=Nrec; nrec++) {
		if (Nrec>1) { print("Analysis "+nrec); showStatus("Analysis "+nrec); }
		//section pour analyse
		selectWindow(nom_ori);
setBatchMode(true);
		if (channels>1)
			if (frames>1)
				run("Duplicate...", "title=["+nom_ori+".temp["+" duplicate frames="+sliceIni+"-"+sliceEnd+" channels="+channel);
			else	run("Duplicate...", "title=["+nom_ori+".temp]"+" duplicate slices="+sliceIni+"-"+sliceEnd+" channels="+channel);
		else run("Duplicate...", "title=["+nom_ori+".temp]"+" duplicate range="+sliceIni+"-"+sliceEnd);
		duplicateid = getImageID();
		// if (bitDepth() != 32) run("32-bit");
		selectImage(duplicateid);

		//binning xy et z de l'image
		if (binax>1 || bintemp>1) {
			print("Binning");
			run("Bin...", "x="+binax+" y="+binax+" z="+bintemp+" bin="+bintype);
		}
	
		//nouvelles dimensions x-y-z apres binning
		getDimensions(largeurBin, hauteurBin,channels, slices, frames);
		nbImagesBin = floor(nbImages/bintemp);
		print("New val:"+nbImagesBin);
		// création de l'image des la map
		mapName = nom_ori+"_"+title+"_"+sliceIni+"_"+sliceEnd;
		if( binax>1)	
			mapName = mapName+"_Bx"+binax;
		if (is_SG)
			mapName = mapName+"_SG"+SG_HWS+"-"+SG_PO+"-"+SG_DO;
		else 
			if (smooth != items2[0])
				mapName = mapName+"_"+smooth;
		if (isSel != -1)
			mapName = mapName+"_Sel";
		if (interpolate) 
			mapName = mapName+"_Interpolate";
		if (method == Tmethod[0]) 
			mapName = mapName+"_Peak";
		if (method == Tmethod[1]) 
			mapName = mapName+"_Slope";
		if (method == Tmethod[2]) 
			mapName = mapName+"_Threshold";
		
		if (Debug) print("Duplicate window " + mapName); 
		duplicateBlack(mapName, "32-bit");
		selectImage(duplicateid);
		if (smooth !=items2[0]) {
			if (is_SG) {
				print("Please Wait during Time Noise Reduction...");
				run("Properties...", "slices="+nbImagesBin+" frames=1");
				sOptions = "half="+SG_HWS+" order="+SG_PO+" derivative="+SG_DO;			
				run("Time Noise Reduce", sOptions);
				print("End of Time Noise Reducing.");
			}
			else {
				run(smooth, "stack");
			}
		}
		filteredid = getImageID();
		selectImage(filteredid);

		//Detection auto sensib min
		Stack.getStatistics(voxelCount, Stmean, Stmin, Stmax, Stsd);
		print("Stack:mean="+Stmean+" max="+Stmax+" min="+Stmin+" sd="+Stsd);
		Ztab = GetZprofile(1, nbImagesBin);
		Array.getStatistics(Ztab, Zmin, Zmax, Zmean, Zsd);
		print("Tab:mean="+Zmean+" max="+Zmax+" min="+Zmin+" sd="+Zsd);		

		// Peak Search parameters
		edge = 1;
		if (sensit<1) {
			tolerance=1;
			amp_threshold=0;
		} else {
			tolerance=(Zmax-Zmin)*tolerancePerCent/100;
			if(is_SG && SG_DO>0) {
				amp_threshold = 0;
				tolerance /= SG_HWS;
			} else {
				amp_threshold = 5*(Zmax-Zmin)/sensit; 
			}
		}		
		print("threshold set to "+amp_threshold);
		
		//selection du premier pt
		makePoint(0, 0);
		Ztab = newArray(nbImagesBin);		
		selectImage(filteredid);
		print("tolerance set to "+tolerance);
		showStatus("Computing new map...Please wait.");

		PeakArrayX = newArray(5);
		PeakArrayY = newArray(5);
		if (method == Tmethod[1]) {
			derivArray = newArray(nbImagesBin);
			tp = newArray(1);
		}
		
		for(xi=0;xi<largeurBin;xi++) {
			if (BM != 1) showProgress(xi/largeurBin);
			for(yi=0;yi<hauteurBin;yi++) {
				for(zi=0; zi < nbImagesBin; zi++) { //yi
					setZCoordinate(zi);
					Ztab[zi] = getPixel(xi,yi);
				}
				selectWindow(mapName);
				PositionDuMax = Array.findMaxima(Ztab, tolerance, edge);
				PositionDuMin = Array.findMinima(Ztab, tolerance, edge);
				pos = 240;
				if (PositionDuMax.length > 0 && PositionDuMin.length > 0) {
					if (sensAna == 1)
						pos = PositionDuMax[0];
					else 			
						pos = PositionDuMin[0];
					if (pos > 1 && pos <(nbImagesBin - 2)) {
						ecart = Ztab[PositionDuMax[0]]-Ztab[PositionDuMin[0]];
						if (ecart > amp_threshold) {
							if (method == Tmethod[1]) {
								Ztab =  AdjFilter(Ztab, 2);
								Ztab = CalcDerivative(tp, Ztab, derivArray, 0); 
								PositionDuMax = Array.findMaxima(Ztab, tolerance);
								PositionDuMin = Array.findMinima(Ztab, tolerance);
								
								if (PositionDuMin.length > 0) {
									pos = PositionDuMax[0];
									Yvoulu = Ztab[PositionDuMin[0]] + (Ztab[PositionDuMax[0]] - Ztab[PositionDuMin[0]])/2;
								} else if (Debug) pos =  160; else pos = 0;
							}
							if (method == Tmethod[2]) { //threshold
								Array.getStatistics(Ztab, PDmin, PDmax, PDmean, PDstdDev);
								Yvoulu = PDmin + (PDmax-PDmin)/2;
								if (sensAna == 1) {
									for (ii=0;ii<nbImages;ii++)
										if (Ztab[ii]>Yvoulu)
											break;
								} else 
									for (ii=0;ii<nbImages;ii++)
										if (Ztab[ii]<Yvoulu)
											break;
								if (ii <nbImages) pos = ii;
								else if (Debug) pos =  240; else pos = 0;
							}
							if ((pos >2) && (pos < nbImages-2))
								if (interpolate) {
									for(jj=-2; jj<3; jj++) {
										PeakArrayX[2+jj] = pos+jj;
										if ((method == Tmethod[0]) && sensAna != 1)
											PeakArrayY[2+jj] = -Ztab[pos+jj];
										else PeakArrayY[2+jj] = Ztab[pos+jj];
									}
									
									if (method == Tmethod[2]) {
										fitFunction = "Straight Line";
										Fit.doFit(fitFunction, PeakArrayX, PeakArrayY);
										a = Fit.p(1);
										b = Fit.p(0);
										pos = (Yvoulu-b)/a;
									} else {
										fitFunction = "Gaussian";
										Fit.doFit(fitFunction, PeakArrayX, PeakArrayY);
										pos = Fit.p(2);
									}
								}
							if(cFrame) pos += sliceIni;
						} else if (Debug) pos =  180; else pos = 0;
					} else if (Debug) pos =  200; else pos = 0;
				} else if (Debug) pos =  220; else pos = 0; /**/
				setPixel(xi,yi, pos);
				selectImage(filteredid);
			}
		}
		selectWindow(mapName);
		run("Remove Outliers...", "radius=2 threshold=10 which=Dark");
		run("Remove Outliers...", "radius=2 threshold=10 which=Bright");

/******** Calibrate ************/
		if (bitDepth() == 32) {
			if (ver >= "1.52q") 
				run("Calibrate...", "function=None unit="+Tunits);
			else
				setMetadata("Info", "Calibration unit:"+Tunits);
		} else 
			if (fps>999)
				run("Calibrate...", "function=[Straight Line] unit=ms text1=[1 100] text2=[1 "+1e5/fps+"]");
			else
				run("Calibrate...", "function=[Straight Line] unit=s text1=[1 100] text2=[1 "+100/fps+"]"); 
		if (FI != 0)
			run("Multiply...", "value="+FI);
		if (PostP ) {
			run("Smooth");
		}		
	
	// Debug = 1;
	// AutoAdjust((bitDepth()==32));
		resetMinAndMax();
		run("16 Colors");
		if (is_SG) 
			if (SG_KO == 0)
				CloseI(filteredid);
			else {
				selectImage(filteredid);
				setBatchMode("show");
				wait(100);
				run("Set... ", "zoom="+zoom*100*binax);
				rename(nom_ori+"_SG"+SG_HWS+"-"+SG_PO+"-"+SG_DO);
				selectWindow( mapName );
			}
				
		// CloseI(duplicateid);
		sliceIni+=nbImages; sliceEnd+=nbImages;
setBatchMode(false);
	}
	selectWindow( mapName );
	run("Set... ", "zoom="+zoom*100*binax);
	if (!isOpen("B&C"))	
		run("Brightness/Contrast...");
	showProgress(1);
	showStatus("Map done.");
	if (overlay==items3[1]) {
		waitForUser("Use the 'Brightness & Contrast tool' to find the correct Greylevel limit,\n Then click 'OK' ");
		selectWindow(mapName);
		getMinAndMax(min, max);
		// print(max);
		GreylevelFilterMinMax(min,max);
		updateDisplay();
	}
	if (overlay==items3[2]) {
		waitForUser("Use the 'Brightness & Contrast tool' to find the correct Greylevel limit,\nthen click 'OK' to paste this map on the stack as an overlay or 'ESC' to not.");
		selectWindow(mapName);
		getMinAndMax(min, max);
		// print(max);
		GreylevelFilterMinMax(min,max);
		updateDisplay();
	}
	if (overlay!=items3[0])
		if (isOpen(mapName)) {
			if (isSel==-1) {
				if (binax>1) {
					selectWindow( mapName );
					run("Duplicate...", " ");
					mapName = getInfo("window.title");
					print(mapName); selectWindow( mapName );
					txt = " width="+largeur*binax+" height="+hauteur*binax+" average interpolation=Bilinear"; print(txt);
					run("Size...",  txt);
					if (Debug) print(txt);
				}
			} 
			selectWindow(nom_ori);
			getSelectionBounds(xSel, ySel, width, height);
			if (isSel != -1) {
				run("Add Image...", "image=["+ mapName +"] x="+xSel+" y="+ySel+" opacity=50 zero");
			} else
				run("Add Image...", "image=["+ mapName +"] x=0 y=0 opacity=50 zero");
			if (isSel==-1) if (binax>1) CloseW(mapName);
		}
	if (is_Hist) run("Histogram");

}

macro "Make IsochroneMap" {
	autoFill();
	Path = getDirectory("imagej") + "Config" + File.separator;
	loadConfigWithName(Path+"auto.txt"); // a creer
	Isochrone_map_start(true); // mode auto
}
/********************** VECTOR MAP *************************/
function createMask(low, high) {
	run("Duplicate...","title=Mask");
	run("8-bit");
	setThreshold(low, high);
	run("Convert to Mask");
	run("Invert LUT");
	run("Invert");
	run("Dilate");
	run("Divide...", "value=255");
	return getImageID();
}

function computeD(id, maskid, axe) {
	selectImage(id);
	run("Duplicate...","title="+axe+"_derivative");
	Sid = getImageID();
	run("32-bit");
	if (axe=="X")
		coor = "x=-0.5 y=0";
	else coor = "x=0 y=-0.5";
	run("Translate...", ""+coor+" interpolation=Bicubic");
	run ("Duplicate...","title="+axe+"1");
	if (axe=="X")
		coor = "x=1 y=0";
	else coor = "x=0 y=1";
	run("Translate...", ""+coor+" interpolation=None");
	imageCalculator("substract",Sid,axe+"1");
	CloseW(axe+"1");
	imageCalculator("multiply",Sid,maskid);
	run("Remove NaNs...", "radius=3");
	return Sid;
}

function EdgeCorrector(id) {
	selectImage(id);
	for (y=0; y<getHeight(); y++) 
		for (x=0; x<2; x++) 
			setPixel(x, y, getPixel(2, y));
		
	for (y=0; y<3; y++) 
		for (x=0; x<getWidth(); x++) 
			setPixel(x, y, getPixel(x, 3));
}

function Vector_map() {
	Vector_map_hist(0);
}

function Vector_map_hist(hist) {
	// requires("1.52f");
	
	bShowIntermediate = 0;
	bShowDerivative = 0;
	bMedianFilter = 0;
	// nBinsHisto = 25;
	ampli = call("ij.Prefs.get", "MAPPING.ampli",-1);
	bin = call("ij.Prefs.get", "MAPPING.bin",-1);
	bsmooth = call("ij.Prefs.get", "MAPPING.bsmooth",0);

	setBatchMode(true);
	// select last image/stack => avoid Log/dialog windows.
	// selectImage(getImageID());
	Winfo=getInfo("window.type");
	print(Winfo);
	if ( !startsWith(Winfo, "Image")) {
		if (lengthOf(Winfo) > 0)
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: selected windows isn't correct"
			 +"<ul>"
			 +"<li>tip: Generally used on an <b>isochronal map</b>"
			 +"</ul>");
		else
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: There are no images open"
			 +"<ul>"
			 +"<li>tip: Usually works on an <b>isochronal map</b>"
			 +"</ul>");
	}
	if (hist != 0)
		requires("1.52f");
	zoom = getZoom();
	run("Duplicate...","title=Src");
	srcid = getImageID();
	init_Common_values();
	print("XYunit="+unit);
	is_Calibrated = false;
	if (bitDepth() == 32) {
		run("Remove NaNs...", "radius=3");
		Tunits = getTag("Calibration unit:");
		if ( lengthOf(Tunits)==0 )
			if ( lengthOf(getTag("Calibration"))>0 ) {
				Tunits = getTag(" Unit:");
				if ( indexOf(Tunits,"\"") != -1 )
					Tunits=replace(Tunits,"\"","");
			}
		if ( lengthOf(Tunits)>0 ) {
			prop = calibrateTime(Tunits);
			factor =  1;
			if (prop !=0)
				is_Calibrated = true;
		}
	} else if ( lengthOf(getTag("Calibration"))>0 ) {
		factor =  1/parseFloat(getTag("b:"));
		is_Calibrated = true;
		Tunits = getTag("Unit");
		Tunits = substring(Tunits, indexOf(Tunits,"\"")+1, lastIndexOf(Tunits,"\""));
		prop = calibrateTime(Tunits);
	} 
	
	if (is_Calibrated) {
		print("Image is calibrated");
		print("  Tunits="+Tunits);
		print("  prop="+prop);
		print("  factor="+factor);
	}	

// Retourne pour avoir origine en bas à gauche	
	run("Flip Vertically");
	run("Duplicate...","title=Vect");
	Vectid = getImageID();
	if (hist == 0) {
		Dialog.create("Parameter:"); {
			if (is_Calibrated) { 
				Dialog.addMessage(" -- INFORMATIONS -- \n Image is calibrated \n "+pixelW+" "+unit+" by pixel\n "+(1/factor)+" "+Tunits+" by pixel value");
			} else Dialog.addMessage(" -- INFORMATIONS -- \n Image is not calibrated");
			Dialog.addNumber("Magnitude factor for vectors: ", ampli, 0, 2, "(-1 = auto)");
			Dialog.addNumber("Density factor for vectors: ", bin, 0, 2, "(-1 = auto)");
			Dialog.addMessage("to compare multiple zone, do not use 'auto'");
			Dialog.addCheckbox("Post-processing Median filter", bMedianFilter);
			Dialog.addCheckbox("Show Angle & Magnitude images", bShowIntermediate);
			Dialog.addCheckbox("Show Derivative X & Y images", bShowDerivative);
			Dialog.addMessage(sCop);
			Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky/vectorMap.html");
			Dialog.show();	
			ampli = Dialog.getNumber();
			bin = Dialog.getNumber();
			bMedianFilter = Dialog.getCheckbox();
			bShowIntermediate = Dialog.getCheckbox();
			bShowDerivative = Dialog.getCheckbox();
			call("ij.Prefs.set", "MAPPING.ampli",ampli);
			call("ij.Prefs.set", "MAPPING.bin",bin);
		}
	}
// test density 
	bintype = "Average";
	if (bin==-1) {
		bin = floor(maxOf(hauteur, largeur)/100)+1;
		print("Density factor is "+bin);
	}
	run("Bin...", "x="+bin+" y="+bin+" bin="+bintype);	
	
//	EdgeCorrector(Vectid);
	maskid = createMask(0, 1);
	// setBatchMode("show"); 
	Xid = computeD(Vectid, maskid, "X");
	Yid = computeD(Vectid, maskid, "Y");
	EdgeCorrector(Xid);	EdgeCorrector(Yid);
/*************		Amplitude     *************/
	imageCalculator("Multiply create 32-bit", Xid, Xid); x2id = getImageID();
	imageCalculator("Multiply create 32-bit", Yid, Yid); y2id = getImageID();
	imageCalculator("Add create 32-bit", x2id, y2id); xy2id = getImageID();
	selectImage(xy2id);
	
	// on calcule l'inverse
	for (y=1; y<hauteur; y++) {
		for (x=1; x<largeur; x++) {
			val = getPixel(x,y);
			if (val != 0)
				setPixel(x,y,pixelW/sqrt(val));
		}
	}
	// on filtre 
	if (bMedianFilter) run("Mean...", "radius=2.0"); 
	
	// on calcule l'histogramme
	N = getHisto(largeur, hauteur, 1);
	// Array.print(N);
	Array.getStatistics(N, minHisto, maxHisto, meanHisto, stdHisto);
	// on filtre selon l'histogramme
	GreylevelFilterMinMax(0,meanHisto*3);
	resetMinAndMax();

	if (hist != 0) {
		Array.getStatistics(N, minHisto, maxHisto, meanHisto, stdHisto);
		print(minHisto);print(maxHisto);print(meanHisto);print(stdHisto);
		Plot.create("Magnitude histogram","Speed ("+unit+"/"+Tunits+")","Counts");
		Plot.setColor("black","lightGray");
		Plot.addHistogram(N, 0);
		Plot.addText("Mean: "+ meanHisto +", SD: " + stdHisto + ", min: " + minHisto + ", max: " + maxHisto, 0.2, 0);
		Plot.update();

		setBatchMode(false); 
		return 0;
	}

/*************		Angle     *************/
	selectImage(srcid);
	duplicateBlack("Angle_"+nom_ori, "32-bit");
	angleid = getImageID();
	selectImage(Xid); run("Mean...", "radius=1.0"); 
	selectImage(Yid); run("Mean...", "radius=1.0"); 
	for (y=1; y<hauteur; y++) 
		for (x=1; x<largeur; x++) {
			selectImage(Xid);
			xval = getPixel(x,y);
			selectImage(Yid);
			yval = getPixel(x,y);
			selectImage(angleid);
			setPixel(x,y,atan2(yval,xval)); // en radians
		}
		
/*************		Vecteurs     *************/	
 	n = largeur*hauteur;
 	xS = newArray(n);
	yS = newArray(n);
	xE = newArray(n);
	yE = newArray(n);
	i = 0;
	selectImage(xy2id);
	getMinAndMax(minmin, maxmax);
	print("Min norme: "+minmin);
	print("Max norme: "+maxmax);
	if (ampli==-1) {
		ampli=6/maxmax;
		print("Magnitude factor is "+ampli);
	}
	for (y=1; y<hauteur; y++) {
		if (BM != 1) showProgress(y/hauteur);
		for (x=1; x<largeur; x++) {
			selectImage(xy2id);
			val = getPixel(x,y);
			if (val !=0){
				selectImage(angleid);
				xS[i+x-1] = x;
				yS[i+x-1] = y;
				xE[i+x-1] = x + cos(getPixel(x,y))*val*ampli;
				yE[i+x-1] = y + sin(getPixel(x,y))*val*ampli;
			}
		}
		i += largeur;
	}
	
	Plot.create("Vector Plot_"+nom_ori,"X Axis","Y Axis");
	Plot.setFrameSize(largeur*zoom*bin, hauteur*zoom*bin);
	Plot.setColor("blue");
	Plot.drawVectors(xS, yS, xE, yE);
	Plot.setLimits(0, largeur, 0, hauteur);	
	Plot.show();
	vectorid = getImageID();

	if (bShowIntermediate) {
		selectImage(angleid);
		setBatchMode("show");
		run("Flip Vertically");
		run("Set... ", "zoom="+zoom*100); 
		resetMinAndMax();
		run("Grays");

		selectImage(xy2id);
		setBatchMode("show"); 
		rename("Magnitude_"+nom_ori);
		run("Set... ", "zoom="+zoom*100);
		setBatchMode("show");
		run("Flip Vertically");
		selectImage(vectorid);
	}
	
	if (bShowDerivative) {
		selectImage(Xid);
		setBatchMode("show");
		run("Grays");
		run("Flip Vertically");
		run("Set... ", "zoom="+zoom*100); 
		selectImage(Yid);
		setBatchMode("show");
		run("Grays");
		run("Flip Vertically");
		run("Set... ", "zoom="+zoom*100); 
		selectImage(vectorid);
	}
	setBatchMode(false); 
}

/********************** CONFIG *************************/
function saveVal(path, str, def) {
	File.append(""+str+"="+call("ij.Prefs.get", str, def), path);
}

function loadConfig() {
	SavPath = getDirectory("imagej") + "Config" + File.separator;
	call("ij.io.DirectoryChooser.setDefaultDirectory", SavPath);	
	path = File.openDialog("Select a configuration file");
	// dir = File.getParent(path);
	// name = File.getName(path);
	loadConfigWithName(path);
}
function loadConfigWithName(name) {
	print(name);
	str = File.openAsString(name);
	lines=split(str,"\n");
	nlines=lengthOf(lines);
	if (nlines > 3) {
		if ( !startsWith(lines[0], "SPIKY parameters file") ) {
			print("not a SPIKY parameters file");
			return;
		}
		if ( !startsWith(lines[1], sVer)) {
			print("Warning: File version differ!");
		}	
		for (i=3;i<nlines;i++) {
			val=split(lines[i],"=");
			if (lengthOf(val) > 1) {
				call("ij.Prefs.set", val[0], val[1] );
				// print(val[0]+"="+val[1]);
			} else print("Error with line "+i+" ("+lines[i]+")");
		}
		print( (nlines-3)+" parameters successfully loaded.");
	} else print("Error: not a SPIKY parameters file.");
}

function saveConfig() {
	SavPath = getDirectory("imagej") + "Config" + File.separator;
	File.makeDirectory(SavPath);
	call("ij.io.DirectoryChooser.setDefaultDirectory", SavPath);
	// print(SavPath);
	f = File.open("");
	path = File.directory+File.name;
	print(path);
	saveConfigWithDir(path);
}

function saveConfigWithDir(path) {
	File.saveString("SPIKY parameters file", path); File.append("", path);
	File.append(sVer, path);
	File.append(sCop, path);
	saveVal(path, "SPIKY.Debug", 0);
	saveVal(path, "SPIKY.PeakAna.tolerance", 15);
	saveVal(path, "SPIKY.PeakAna.TTP.thresholdDetectionDEbPeak", 5);
	
	saveVal(path, 	"SPIKY.PeakAna.smooth"	, 1);
	
	//DISPLAY
	saveVal(path, "SPIKY.PeakAna.SPWHDP",1);
	saveVal(path,	"SPIKY.PeakAna.DerivativeSig",0);
	saveVal(path,	"SPIKY.PeakAna.Dbaseline",1);
	saveVal(path, 	"SPIKY.PeakAna.DVmax",0);
	saveVal(path, 	"SPIKY.PeakAna.Dthreshold",1);
	items4 = newArray("Automatic","Manual");
	saveVal(path, 	"SPIKY.PeakAna.autoDetect",items4[0]);
	saveVal(path, 	"SPIKY.PeakAna.ASfS",0);
	saveVal(path, 	"SPIKY.PeakAna.SSSL",0);

	saveVal(path, 	"SPIKY.PeakAna.FW",1);
	saveVal(path, 	"SPIKY.PeakAna.HW",1);
	saveVal(path, 	"SPIKY.PeakAna.x1P",30);
	saveVal(path, 	"SPIKY.PeakAna.x2P",90);

	saveVal(path, 	"SPIKY.PeakAna.summarize",1);
	saveVal(path, 	"SPIKY.PeakAna.decimal",6);

	saveVal(path, 	"SPIKY.PeakAna.Vmax",0);

	saveVal(path, 	"SPIKY.PeakAna.AUP",0);
	saveVal(path, 	"SPIKY.PeakAna.decay",1);
	saveVal(path, 	"SPIKY.PeakAna.pdecay",66);

	saveVal(path, 	"SPIKY.PeakAna.ShowSumTable",1);
}

/********************** PARAMETER MAP *************************/
function Parameter_map() {
	srcName = getInfo("window.title");
	Winfo=getInfo("window.type");
	if ( !startsWith(Winfo, "Image")) {
		if (lengthOf(Winfo) > 0)
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: selected windows isn't correct"
			 +"<ul>"
			 +"<li>tip: Use a <b>Z-stack images</b> or select a <b>Result table</b>"
			 +"</ul>");
		else
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: There are no images open"
			 +"<ul>"
			 +"<li>tip: Open a <b>Z-stack images</b>"
			 +"</ul>");
	}	
	getLocationAndSize(xwin, ywin, dxwin, dywin);
	zoom = getZoom();
	sel = selectionType;
	if (sel > -1 && sel < 4) {
		run("Duplicate...", "duplicate");
		run("Set... ", "zoom="+zoom*100);
		if (sel != 0) {
			setBackgroundColor(0, 0, 0);
			run("Clear Outside", "stack");
		}
	}
	BM=1; strVunit = "UA"; sensAna = 1;
	interpolate_bk = interpolate;
	interpolate = false;
	videoid = getImageID(); 
	init_XYT_values();
	sliceIni = 1;
	sliceEnd = nSlices;
	AmpPerCent = 20;
	MatrixSize = 5;
	showTable = false;
		
	if (!isKD) print("key_Down Class not found!Spiky cannot manage the ESC key\nIf you stop the macro, please verify the 'Analysis options'"); // else print("key_Down found"); 
	if (!isHRtime) print("HRtime Class not found! Spiky will not use it.");
	
	selectImage(videoid);
	// detect sens de l'analyse
	Ztab = GetZprofile(2, nSlices);
	Array.getStatistics(Ztab, Zmin, Zmax, Zmean, ZstdDev);
	// print("Image:mean="+Zmean+" max="+Zmax+" min="+Zmin+" sd="+ZstdDev);
	if ((Zmax - Zmean) < (Zmean-Zmin))
		sensAna = 0; //neg
	else sensAna = 1; //pos	
	
	txtVunit = "("+strVunit+") ";
	txtHunit = "("+Tunits+") ";
	// print("v:"+txtVunit); print("h:"+txtHunit);
	Dialog.create("Parameters to analyse"); {
		binax = parseFloat(call("ij.Prefs.get", "MAPPING.binax","1"));
		bintemp = parseFloat(call("ij.Prefs.get", "MAPPING.bintemp","1"));

		sens = newArray("negative","positive");
		Dialog.addChoice("Sens of analysis", sens,sens[sensAna]);
		Dialog.addNumber("Axial binning (x"+fromCharCode(0x00B1)+")", binax);
		Dialog.addNumber("Temporal binning (x"+fromCharCode(0x00B1)+")", bintemp);
		Dialog.addMessage("Limit time zone to");
		Dialog.addNumber("first slice", sliceIni);
		Dialog.addNumber("last slice", sliceEnd);
		
//		Dialog.addNumber("If manual Adj/Avg smoothing ("+fromCharCode(0x00B1)+" n, 0=none)",call("ij.Prefs.get", "SPIKY.PeakAna.smooth",10)); 
		Dialog.addMessage("Adj/Avg smoothing: ");	
		// Dialog.addNumber(" ",call("ij.Prefs.get", "SPIKY.PeakAna.smooth",-1)); 
		Dialog.addNumber("0=none, -1=auto or any values ("+fromCharCode(0x00B1)+")",call("ij.Prefs.get", "SPIKY.PeakAna.smooth",-1),0,2,""); 
		TdecayStr =  "RW"+call("ij.Prefs.get", "SPIKY.PeakAna.x2P",80)+" ";
		analyseU = newArray(txtHunit,txtVunit,txtHunit,txtHunit,strVunit+"/"+strHunit,txtHunit);
		analyseA = newArray("FWHM "+ txtHunit,"Amplitude "+txtVunit,"Tmax " + txtHunit,TdecayStr + txtHunit,"dV/dT ("+strVunit+"/"+strHunit+")","tau decay " + txtHunit);
		Dialog.addChoice("Analysis", analyseA);
 		Dialog.addMessage("Change RWxx value in 'analysis options'");
		Dialog.addCheckbox("Show Peak Analysis result window",false);
		Dialog.addCheckbox("Advanced settings",false);
		Dialog.addMessage(sCop);
		Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky/parameterMap.html");
		Dialog.show();
		
		// selectImage(PlotId); 
		key=0;
		callValues(); 
		if (startsWith(Dialog.getChoice(),sens[0]))
			sensAna = 0;
		else sensAna = 1;
		binax = Dialog.getNumber();
		bintemp = Dialog.getNumber();
		sliceIni = Dialog.getNumber();
		sliceEnd = Dialog.getNumber();
		smooth = Dialog.getNumber();
		// call("ij.Prefs.set", "MAPPING.binax",toString(binax));		
		// call("ij.Prefs.set", "MAPPING.bintemp",toString(bintemp));		
		call("ij.Prefs.set", "SPIKY.PeakAna.smooth",smooth);
		
		// binning xy et z de l'image
		selectImage(videoid); bintype = "Average";
		if (binax>1 || bintemp>1) {
			run("Bin...", "x="+binax+" y="+binax+" z="+bintemp+" bin="+bintype);
		}
		getDimensions(lgBin, htBin, channels, slices, frames);
		
		analParam = Dialog.getChoice();
		for (i=0; i<analyseA.length; i++) { 
			if (analParam == analyseA[i]) {
				NanalParam = i;
				break;
			}	 		
		}
		if (! Dialog.getCheckbox()) {
			call("ij.Prefs.set", "SPIKY.PeakAna.ShowSumTable",0);
		} else showTable = true;
		if (Dialog.getCheckbox()) {
			Dialog.create("Advanced Parameters"); {
				Dialog.addMessage("Limit 3D pixel analysis to");
				Dialog.addNumber("% from biggest min-max difference", AmpPerCent);
				Dialog.addNumber("matrix for analysis (NxN)", MatrixSize);
				Dialog.addMessage("These parameters shouldn't be changed unless the automatic analysis failed.\nThese parameters won't be saved for the next session");
				Dialog.addMessage(sCop);
				Dialog.addHelp("https://pccv.univ-tours.fr/ImageJ/Spiky/parameterMap.html");
				Dialog.show();
				
				AmpPerCent = Dialog.getNumber();
				MatrixSize = Dialog.getNumber();
			}
		}
	}
setBatchMode(true);	

	// decoupage en 5x5
		// Rq : pas de selection !!!
	minL = largeur/MatrixSize; minH = hauteur/MatrixSize;	ampDiff = 0;
	for (xi=0; xi<MatrixSize; xi++)
		for (yi=0; yi<MatrixSize; yi++) {
			selectImage(videoid);
			makeRectangle(xi*minL, yi*minH, minL, minH);
			Ztab = GetZprofile(2, nSlices);
			Array.getStatistics(Ztab, Zmin, Zmax, Zmean, ZstdDev);
			if (ampDiff < abs(Zmax-Zmin)) {
				ampDiff = abs(Zmax-Zmin);
				xisav = xi;
				yisav = yi;
			}
	}
	ampDiff*=(AmpPerCent/100);
	print("First pass: "+ ampDiff+" in ("+xisav+","+yisav+")");

	makeRectangle(xisav*minL, yisav*minH, minL, minH);

	run("Select None");
	plot3Dimage(videoid);
	PlotId = getImageID();
	
	if (peakDetection(PlotId,sensAna)) {
	} else {
		CloseI(PlotId); 
		recallValues();
		exit("<html>"
				+"<h1>Spiky</h1>"
				+" <u>Warning</u>: No peak found !"
				+"<ul>"
				+"<li>tip 1: Decrease parameter <b>Minimum peak amplitude</b>"
				+"<li>tip 2: look at the advanced parameters</b>"
				+"</ul>");	
	} 
	selectImage(videoid);
	call("ij.Prefs.set", "SPIKY.PeakAna.ShowSumTable",1);
	run("Select None");
	
setBatchMode(false);	
	if (isKD) {
		run("key Down");
		//flush keyboard buffer
		// call("key_Down.flush");
	} /* */
	call("ij.gui.ImageWindow.setNextLocation", xwin, ywin+dywin);
	newImage(analParam, "32-bit black", lgBin, htBin, 1);
	run("Properties...", "unit="+unit+" pixel_width="+pixelW+" pixel_height="+pixelH+"");
	run("Red");
	ImageId = getImageID(); 
	setBatchMode("show"); wait(100); 
	run("Set... ", "zoom="+zoom*100); wait(100); run("Out [-]"); wait(100); run("In [+]");
	if (isKD) { 
		selectImage(ImageId);
		// Add key listener
		run("key Down");
		//flush keyboard buffer
		// call("key_Down.flush");
		// selectImage(videoid);
	}/* */
setBatchMode(true);	
	if (isHRtime) lastTime = parseInt(call("HRtime.gettime"));
	print("-- Analysis starts, please wait! --\nTips: Select the parameter map window,\n then use the 'B&C' window to see the map construction!");
	// showStatus("Please wait. Do not touch any window !");
	
	call("ij.Prefs.set", "SPIKY.PeakAna.ShowSumTable",0);
	if (!startsWith(analParam, "tau decay"))
		call("ij.Prefs.set", "SPIKY.PeakAna.decay",0);
	if (!startsWith(analParam, "dV/dT"))
		call("ij.Prefs.set", "SPIKY.PeakAna.Vmax",0);
	
	if (!isOpen("B&C"))
		run("Brightness/Contrast...");

	if (isKD) key=call("key_Down.get", 1);
	 // print("ImageId is "+ImageId);
	Enom="Exception";
	for (y=0;y<= (htBin);y++) {
		if (isOpen(Enom)) { break; }

		// trap keys only when image id is active, return ESC and F1 to F12 keys and pass others keys to ImageJ
		if (!isOpen(ImageId)) break;
		if (isKD) key = call("key_Down.get", 1);

		showProgress(-y/htBin);
		if (key == 27) { IJ.log("you pressed ESC: recall backup !"); break; }
		for (x=0;x<= (lgBin);x++) {
			selectImage(videoid);
			makeRectangle(x, y, 1, 1);
			plot3Dimage(videoid);
			PlotId = getImageID();
			if (peakDetection(PlotId,sensAna)) {
				selectImage(ImageId);
				setPixel(x,y,valMoy[NanalParam]);
				// print("X="+x+", Y="+y+", val="+valMoy[NanalParam]);
			} 
			CloseI(PlotId); 
		}
		selectImage(ImageId);
		setBatchMode("show");
	}
	if (isKD) { selectImage(ImageId); call("key_Down.restore"); }
	if (isKD) { selectImage(videoid); call("key_Down.restore"); }
setBatchMode(false);
	interpolate = interpolate_bk;
	recallValues();
	selectImage(videoid);
	run("Select None");
	if (isHRtime) {
		laps = (parseInt(call("HRtime.gettime")) - lastTime)/1000.0;
		showStatus("Done! laps time: "+laps+" ms");
		print("Done! laps time: "+laps+" ms");
	} else { print("Done!"); showStatus("Done!");}
	BM=0;
	selectImage(ImageId);
	run("Calibrate...", "function=None unit="+analyseU[NanalParam]);
}

function recallValues() {
	SavPath = getDirectory("imagej") + "Config" + File.separator;
	loadConfigWithName(SavPath+"temp.sav");
}

function callValues() {
	SavPath = getDirectory("imagej") + "Config" + File.separator;
	File.makeDirectory(SavPath);
	saveConfigWithDir(SavPath+"temp.sav");
	
	call("ij.Prefs.set", "SPIKY.PeakAna.SPWHDP",0);
//	call("ij.Prefs.set", "SPIKY.PeakAna.tolerance",50); //15
	// call("ij.Prefs.set", "SPIKY.PeakAna.",0);
	call("ij.Prefs.set", "SPIKY.PeakAna.SSSL",0);
	call("ij.Prefs.set", "SPIKY.PeakAna.TTP.thresholdDetectionDEbPeak",4)
	call("ij.Prefs.set", "SPIKY.PeakAna.FW",1);

	call("ij.Prefs.set", "SPIKY.PeakAna.DVmax",0);
	call("ij.Prefs.set", "SPIKY.PeakAna.Dbaseline",0);
	call("ij.Prefs.set", "SPIKY.PeakAna.Dthreshold",0);
	
	// call("ij.Prefs.set", "SPIKY.PeakAna.x1P",20);
	// call("ij.Prefs.set", "SPIKY.PeakAna.x2P",80);
	call("ij.Prefs.set", "SPIKY.PeakAna.DerivativeSig",0);
	call("ij.Prefs.set", "SPIKY.PeakAna.HW",1);

	call("ij.Prefs.set", "SPIKY.PeakAna.Vmax",1);
	call("ij.Prefs.set", "SPIKY.PeakAna.AUP",0);
	call("ij.Prefs.set", "SPIKY.PeakAna.decay",1);
	call("ij.Prefs.set", "SPIKY.PeakAna.summarize",1);
	call("ij.Prefs.set", "SPIKY.PeakAna.ShowSumTable",1);
	call("ij.Prefs.set", "SPIKY.PeakAna.decimal",6)
}

function Drift_Removal_fromMenu() {
	if ( !startsWith(getInfo("window.type"), "Plot"))
		exit("<html>"
			 +"<h1>Spiky</h1>"
			 +"<u>Warning</u>: Selected window doesn't seems to be a plot"
			 +"<ul>"
			 +"<li>tip: Drift Removal works only on <b>plot file</b>"
			 +"</ul>");	
	Plot.getValues(arrayX, arrayYraw); //récupération des valeurs du plot
	Drift_Removal(arrayX, arrayYraw, false);
	//De-allocating 
	arrayX=0; arrayYraw=0;
}

function Drift_Removal(X, Y, auto) {
	requires("1.51s");
	if (!auto) {
		if ( !startsWith(getInfo("window.type"), "Plot"))
			exit("<html>"
				 +"<h1>Spiky</h1>"
				 +"<u>Warning</u>: Selected window doesn't seems to be a plot"
				 +"<ul>"
				 +"<li>tip: Drift Removal works only on <b>plot file</b>"
				 +"</ul>");	
		name = getInfo("window.title");

		Vaxis = eval("script","WindowManager.getActiveWindow().getPlot().getLabel('y')");
		strVaxis = extractLabel(Vaxis,"l");
		strVunit = extractLabel(Vaxis,"u");
		if (Debug) {
			IJ.log("Y label: " + strVaxis);
			IJ.log("Y unit: " + strVunit);
		}
		Haxis = eval("script","WindowManager.getActiveWindow().getPlot().getLabel('x')");
		strHaxis = extractLabel(Haxis,"l");
		strHunit = extractLabel(Haxis,"u");
		if (Debug) {
			IJ.log("Y label: " + strHaxis);
			IJ.log("Y unit: " + strHunit);
		}
		run("Close");
	}
	NMax = lengthOf(X);
	arrayDR = newArray(NMax);
	txtVunit = " ("+strVunit+") ";
	txtHunit = " ("+strHunit+") ";

	Array.getStatistics(Y, Ymin);
	Xmin = 0;
	while (Y[Xmin] != Ymin) { Xmin++; }
	
	// fitFunction = "4th Degree Polynomial";
	fitFunction = "Straight Line";
	// fitFunction = "3rd Degree Polynomial";
	Fit.doFit(fitFunction, X, Y);
	// Fit.plot();
	
	Fmin = Fit.f(X[Xmin]);
	for(ii=0; ii<NMax; ii++)
		arrayDR[ii] = Y[ii] - Fit.f(X[ii]) + Fmin;
	
	if (!auto)
		Plot.create(name+"_DR", strHaxis + txtHunit, strVaxis + txtVunit, X, arrayDR);
	else 
		return arrayDR;
}

/********************** Common function *************************/
function CloseW(nom) {
	if (isOpen(nom)) {
		selectWindow(nom);
		run("Close");
		do { wait(10); } while (isOpen(nom));
	}
}

function CloseI(id) {
	if (isOpen(id)) {
		selectImage(id);
		run("Close");
		do { wait(10); } while (isOpen(id));
	}
}

// This function returns the value of the specified tag as a string. 
// Returns "" if the tag is not found.
function getTag(tag) {
	info = getImageInfo();
	index1 = indexOf(info, tag);
	if (index1==-1) return "";
	index1 = indexOf(info, ":", index1);
	if (index1==-1) return "";
	index2 = indexOf(info, "\n", index1);
	value = substring(info, index1+1, index2);
	while (startsWith(value, " ")) {
		value = substring(value, 1 );
	}
	return value;
}
  
//Trouve l'indice de la valeur val dans le tableau val
function findIndice(tab, val) {
	i=0;
	while (tab[i]<val) 
		{ i++; }
	return i;
}

function roundn(num, n) {
	return parseFloat(d2s(num,n))
}

/********************** Common classUtil *************************/
function testLib(lib) {
	if(startsWith(eval("script","Class.forName(\""+lib+"\")"),"class"))
		return true;
	return false; 
}

function testLiborExitI(lib,info) {
	if (!testLib(lib))
		exit("<html>"
			+"<h1>Spiky</h1>"
			+"<u>Error</u>: "+lib+" class not found"
			+"<ul>"
			+"<li>tip: "+info+"</b>"
			+"</ul>");
}

function testLiborExit(lib) {
	testLiborExitI(lib,"download and install "+lib+".jar");
}

function getSpikyBatchArgumentValue(argumentText, key) {
	prefix = key + "=";
	startIndex = indexOf(argumentText, prefix);
	if (startIndex < 0)
		return "";
	valueStart = startIndex + lengthOf(prefix);
	if (valueStart >= lengthOf(argumentText))
		return "";
	valueEnd = indexOf(argumentText, ";", valueStart);
	if (valueEnd < 0)
		valueEnd = lengthOf(argumentText);
	if (valueEnd <= valueStart)
		return "";
	return substring(argumentText, valueStart, valueEnd);
}
