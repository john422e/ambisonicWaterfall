(
// server options
o = Server.default.options;
o.numOutputBusChannels = 4;
o.numOutputBusChannels.postln;
s.boot;
)
(
// SYNTH, LISTENER, GLOBALS, BUFFER, FUNCTIONS
~stereo = True; // for testing
~size = 2048;
SynthDef(\brickwall, {
	arg location=0, id=0, filterLag=30, ampLag=30;
	var sig, chain, channels=1, size=~size, locations, azim;
	//locations = [pi, 3pi/4, pi/2, pi/4, 0, 7pi/4, 3pi/2, 5pi/4]
	locations = (0..7).linlin(1, 8, -pi, pi);
	//location.poll;
	azim = Select.kr(location, locations);
	//azim = MouseX.kr(-pi, pi);
	//azim = SinOsc.kr(0.15).range(-pi, pi).poll;
	sig = PlayBuf.ar(channels, \buf.kr(0), BufRateScale.ir(\buf.kr(0)), loop: 1);
	chain = FFT.new( LocalBuf(size), sig); // provide buffer for FFT data and signal
	chain = PV_BrickWall(chain, \hpf.kr(20, filterLag).linlin(20, 20000, 0, 1)); // high pass
	chain = PV_BrickWall(chain, \lpf.kr(20000, filterLag).linlin(20, 20000, -1, 0)); // low pass

	sig = IFFT(chain);
	//sig = FoaEncode.ar(sig, FoaEncoderMatrix.newOmni);
	sig = FoaEncode.ar(sig, FoaEncoderMatrix.newDirection ); // try HoaEncodeMatrix
	//sig = FoaPush.ar(sig, MouseX.kr(-pi/2, pi/2)).poll;
	sig = FoaTransform.ar(sig, 'rotate', azim);
	if( ~stereo == True,
		{ sig = FoaDecode.ar(sig, FoaDecoderMatrix.newStereo, mul: \amp.kr(0.0, ampLag) ) },
		{ sig = FoaDecode.ar(sig, FoaDecoderMatrix.newPanto, mul: \amp.kr(0.0, ampLag) ) }; // try  HoaMatrixDecoder
	);
	SendPeakRMS.kr( sig, 20, 3, "/replyAddress", id );
	Out.ar(\out.kr(0), sig);
}).add;

// amp listener
~ampThresh = 0.000; // how to handle this?
o = OSCFunc( { arg msg;
	var id=msg[2], peak=msg[3], rms=msg[4];
	if( peak > ~ampThresh, {
		//~scanning = False;
		//"peak: %, rms: %".format(msg[3], msg[4]).postln;
		//[msg[1], id].postln;
		~peakRanks[id] = peak;
		//[~hpf, ~lpf, ~bandSize].postln;
	});
}, '/replyAddress');

~path = PathName.new(thisProcess.nowExecutingPath).parentPath ++ "st6.wav";
b = Buffer.read(s, ~path);

~fullReset = {
	arg synths, fadeTime=1, amp=0.1;
	synths.do( {
		arg synth;
		var hpf=0, lpf=20000;
		synth.set(\ampLag, fadeTime, \filterLag, fadeTime, \hpf, hpf, \lpf, lpf, \amp, amp);
	});
};

~randomReset = {
	arg fadeTime=1, spacingMax=9, amp=0.75;
	// make these local vars here, get rid of globals
	// random filter settings, turn all on
	~bandSize = rrand(10, 200); // random bandSize
	~spacing = rrand(1, spacingMax).postln; // random number of bands between each synth
	~arraySize = ~spacing * 8;
	~fund = rrand(50, 100); // random fundamental 50 - 100 Hz
	~bands = Array.series(~arraySize, ~fund, ~bandSize);
	// set synths
	~synths.do( {
		arg synth, i;
		var hpf, lpf;
		hpf = ~bands[i*~spacing];
		lpf = ~bands[i*~spacing] + ~bandSize;
		synth.set(\ampLag, fadeTime, \filterLag, fadeTime, \hpf, hpf, \lpf, lpf, \amp, amp);
	});
};

~setAmps = {
	arg synths, amp, ampLag=0.01;
	synths.do( {
		arg synth;
		synth.set(\ampLag, ampLag, \amp, amp);
	});
};

~filterCycle = {
	// get loudest synth and turn off
	Task( {
		7.do( {
			~loudest = ~peakRanks.maxIndex;
			~synths[~loudest].set(\ampLag, 1, \amp, 0.0);
			3.wait;
			~peakRanks[~loudest] = 0;
			[~loudest, ~peakRanks].postln;
		});
		3.wait;
		~randomReset.value(0.01, amp: 0.0);
		1.5.wait;
		~setAmps.value(~synths, 0.75);
	}).start;
};
)


(
// make 8 synths, turned off, filters open
~synths = Array.fill(8, {
	arg i;
	var synth;
	synth = Synth.new(\brickwall, [
		\amp, 0.0,
		\location, i,
		\hpf, 0,
		\lpf, 20000,
		\id, i
	]);
	synth;
});
// to store amp values for each synth
~peakRanks = Array.fill(8, { 0 } );
)

(
// PART 1, filters open, soft
~setAmps.value(~synths, 0.1, 0.5);
)

(
// PART 2, random filter setting, 2 minute amp/filter fade
// random filter settings, turn all on
~randomReset.value(120, 5);
)

(
// PART 3, turn off one at a time, 3 seconds each, loudest until one remaining
~iterations = 3;
Task( {
	~iterations.do( {
		~filterCycle.value();
		25.5.wait; // enough time for cycle to complete
		12.wait; // additional wait time
	});
}).start;
)

(
// Part 4, fade to open filter
~fullReset.value(~synths, 180);
)

(
var numBands=8;
var minFreq=60;
var minBandSize=130;

p = minFreq;
numBands.do( {
	arg i;
	var power = i+1, bandSize, lowFreq, highFreq;
	bandSize = minBandSize * power;
	lowFreq = p;
	highFreq = p + bandSize;
	["BAND:", bandSize, "RANGES:", lowFreq, highFreq].postln;
	// set p
	p = highFreq;
});
)





(
// all on, filters open, lower amp, 2 minute fade
~synths.do( {
	arg synth;
	synth.set(\ampLag, 120, \filterLag, 120, \hpf, 0, \lpf, 20000, \amp, 0.08);
});
)

(
// random filter settings, turn all on
~bandSize = rrand(10, 200); // random bandSize
~spacing = rrand(1, 9); // random number of bands between each synth
~arraySize = ~spacing * 8;
~fund = rrand(50, 100); // random fundamental 50 - 100 Hz
~bands = Array.series(~arraySize, ~fund, ~bandSize);
// set synths
~synths.do( {
	arg synth, i;
	var hpf, lpf;
	hpf = ~bands[i*~spacing];
	lpf = ~bands[i*~spacing] + ~bandSize;
	synth.set(\ampLag, 120, \filterLag, 120, \hpf, hpf, \lpf, lpf, \amp, 0.75);
});
)
s.meter;
(
// get loudest synth and turn off
~loudest = ~peakRanks.maxIndex;
~synths[~loudest].set(\ampLag, 1, \amp, 0.0);
Task( {
	1.wait;
	~peakRanks[~loudest] = 0;
	[~loudest, ~peakRanks].postln;
}).start;
)


~peakRanks.maxIndex;

(
~scanning = True;
~bandSize = 50;
~hpf = 100;
~lpf = ~hpf + ~bandSize;
~timeGrain = 0.05;

/*
can try this scanning thing to find loud bands,
OR just do the random thing and listen to each band and sort them by amplitude to remove one by one or make subgroups
*/

r = Task.new( {
	loop {
		if( ~scanning == True, {
			~hpf = ~hpf + 1;
			~lpf = ~hpf + ~bandSize;
			x.set(\hpf, ~hpf, \lpf, ~lpf);
			"scanning".postln;
		});
		~timeGrain.wait;
	};
});
)

r.start;
(
// reset
~bandSize = 100;
~hpf = 50;
)
~scanning = True;
r.reset;
r.start;



(
~size = 60;
~bands = Array.series(16, 60, ~size);
~synths = Array.fill(8, {
	arg i;
	var synth;
	synth = Synth.new(\brickwall, [
		\amp, 0.5,
		\location, i,
		\hpf, ~bands[i*2],
		\lpf, ~bands[i*2] + ~size
	]);
	synth;
});
)


(
~size = 180;
~bands = Array.series(24, 60, ~size);
)
(
// set new bands
~synths.do( {
	arg synth, i;
	synth.set(\hpf, ~bands[i*3], \lpf, ~bands[i*3] + ~size);
});
)

(
// select on
~on = [0, 1, 0, 0, 1, 0, 0, 1];
~synths.do( {
	arg synth, i;
	if( ~on[i] == 1, { synth.set(\amp, 1.0) }, { synth.set(\amp, 0.0) } );
});
)


(
// build synth array
~synths = 8.collect( {
	arg synth;
	Synth(\brickwall);
});
)




(
~spacing = 2;
~arraySize = ~spacing * 8;
// for APC40
MIDIdef.cc( \gain, {
	arg val, num, chan, src;
	var amp, cc;
	amp = val.linlin(0, 127, -60, 0);

	// controls 48-55
	if( (num >= 48) && (num <= 55), {~synths[num-48].set(\amp, amp.dbamp) });
	// control 14 for global scaling of band size
	if( num == 14, {
		// for scaling band size
		var step, bands;
		step = val.linlin(0, 127, 10, 200);
		bands = Array.series(~arraySize, 60, step);
		~synths.do( {
			arg synth, i;
			var hpf, lpf;
			hpf = bands[i*~spacing];
			lpf = bands[i*~spacing] + step;
			[hpf, lpf].postln;
			synth.set(\hpf, hpf, \lpf, lpf);
		});
	});
	// control 15 for band separation
	if( num == 15, {
		var step, bands;
		step = val.linlin(0, 127, 10, 200);
		bands = Array.series(~arraySize, 60, step);
		~spacing = val.linlin(0, 127, 1, 9).round(1);
		~arraySize = ~spacing * 8;
		~synths.do( {
			arg synth, i;
			var hpf, lpf;
			hpf = bands[i*~spacing];
			lpf = bands[i*~spacing] + step;
			[hpf, lpf].postln;
			synth.set(\hpf, hpf, \lpf, lpf);
		});
	});

});
)






MIDIIn.connectAll;
MIDIFunc.trace(true);
MIDIFunc.trace(false);
(
MIDIdef.cc( \rev, {
	arg val, num, chan, src;
	var amp, cc, hpfThresh, range=25;
	amp = val.linlin(0, 127, -60, 0);
	// amps, controls 0-7
	if( (num >= 0) && (num <= 7), { ~synths[num].set(\amp, amp.dbamp) });
	// filter cutoffs, controls 16-23
	if( (num >=16) && (num <=23), {
		cc = num - 16;
		hpfThresh = val.linexp(0, 127, 100, 500);
		hpfThresh.postln;
		~synths[cc].set(\hpf, hpfThresh, \lpf, hpfThresh + range );
	});
	// pans, 32-39, 64-71
	if( (num >= 32) && (num <= 39), {
		"PAN LEFT".postln;
		cc = num - 32;
		~synths[cc].set(\pan, -1);
	});
	if( (num >= 64) && (num <= 71), {
		"PAN RIGHT".postln;
		cc = num - 64;
		~synths[cc].set(\pan, 1);
	});

});
)

~synths[0].set(\hpf, 100, \lpf, 200);
