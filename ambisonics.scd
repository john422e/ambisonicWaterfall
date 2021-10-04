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


o = Server.default.options;
o.numOutputBusChannels.postln;
o.numOutputBusChannels = 4;

s.quit;
s.boot;

s.numChannels
s.meter(numOuts: 8);
// break up field recording bands to 8 speakers
// can explore all ratios 1-8--use nanoKontrol
// try using mishel falls track
// look for loudest and softest amp combos
// map 8 sliders to consistantly be low to high, but have the speaker mapping randomized each time

~path = PathName.new(thisProcess.nowExecutingPath).parentPath ++ "st6.wav";
b = Buffer.read(s, ~path);
b.play;
~size = 2048;
(
SynthDef(\brickwall, {
	arg location=0;
	var sig, chain, channels=1, size=~size, locations, azim;
	//locations = [pi, 3pi/4, pi/2, pi/4, 0, 7pi/4, 3pi/2, 5pi/4]
	locations = (0..7).linlin(1, 8, -pi, pi);
	//location.poll;
	azim = Select.kr(location, locations);
	//azim = MouseX.kr(-pi, pi);
	//azim = SinOsc.kr(0.15).range(-pi, pi).poll;

	sig = PlayBuf.ar(channels, \buf.kr(0), BufRateScale.ir(\buf.kr(0)), loop: 1);
	chain = FFT.new( LocalBuf(size), sig); // provide buffer for FFT data and signal
	chain = PV_BrickWall(chain, \hpf.kr(20).linlin(20, 20000, 0, 1)); // high pass
	chain = PV_BrickWall(chain, \lpf.kr(20000).linlin(20, 20000, -1, 0)); // low pass

	sig = IFFT(chain);
	//sig = FoaEncode.ar(sig, FoaEncoderMatrix.newOmni);
	sig = FoaEncode.ar(sig, FoaEncoderMatrix.newDirection );
	//sig = FoaPush.ar(sig, MouseX.kr(-pi/2, pi/2)).poll;
	sig = FoaTransform.ar(sig, 'rotate', azim);
	sig = FoaDecode.ar(sig, FoaDecoderMatrix.newPanto, mul: \amp.kr(0.0) );

	Out.ar(\out.kr(0), sig);
}).add;
)
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
// all on
~synths.do( {
	arg synth;
	synth.set(\amp, 1.0);
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
