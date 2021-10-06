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
	synths = synths.scramble;
	synths.do( {
		arg synth;
		var hpf=0, lpf=20000;
		synth.set(\ampLag, fadeTime, \filterLag, fadeTime, \hpf, hpf, \lpf, lpf, \amp, amp);
	});
};

~randomReset = {
	arg ampFadeTime=1, filterFadeTime=1, spacingMin=1, spacingMax=9, amp=0.75;
	// make these local vars here, get rid of globals
	// random filter settings, turn all on
	~bandSize = rrand(10, 200); // random bandSize
	~spacing = rrand(spacingMin, spacingMax); // random number of bands between each synth
	~arraySize = ~spacing * 8;
	~fund = rrand(50, 100); // random fundamental 50 - 100 Hz
	~bands = Array.series(~arraySize, ~fund, ~bandSize);
	// set synths
	~synths.do( {
		arg synth, i;
		var hpf, lpf;
		hpf = ~bands[i*~spacing];
		lpf = ~bands[i*~spacing] + ~bandSize;
		synth.set(\ampLag, ampFadeTime, \filterLag, filterFadeTime, \hpf, hpf, \lpf, lpf, \amp, amp);
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
	arg spacingMin=1, spacingMax=9;
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
		~randomReset.value(0.01, 0.01, spacingMin, spacingMax, amp: 0.0);
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
// FORM
Task( {
	"PART 1".postln;
	// PART 1, filters open, soft
	~setAmps.value(~synths, 0.1, 0.5);
	15.wait;
	"PART 2".postln;
	// PART 2, random filter setting, 2 minute amp/filter fade
	// random filter settings, turn all on
	~randomReset.value(150, 135, 2, 5);
	135.wait;
	"PART 3".postln;
	// PART 3, turn off one at a time, 3 seconds each, loudest until one remaining
	~iterations = 4;
	Task( {
		~iterations.do( {
			arg i;
			var spacingMin=(i+1), spacingMax=spacingMin+5;
			~filterCycle.value(spacingMin, spacingMax);
			25.5.wait; // enough time for cycle to complete
			12.wait; // additional wait time
		});
	}).start;
	150.wait;
	"PART 4".postln;
	// Part 4, fade to open filter
	~fullReset.value(~synths, 180);
	180.wait;
	"PART 5".postln;
	// Part 5, end—turn off one at a time
	Task( {
		~synths = ~synths.scramble;
		~synths.do( {
			arg synth;
			synth.set(\ampLag, 0.1, \amp, 0.0);
			3.wait;
		});
	}).start;
}).start;
)

NamedControl