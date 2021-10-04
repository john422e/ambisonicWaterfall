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



// break up field recording bands to 8 speakers
// can explore all ratios 1-8--use nanoKontrol
// try using mishel falls track
// look for loudest and softest amp combos
// map 8 sliders to consistantly be low to high, but have the speaker mapping randomized each time

~path = "/Users/johneagle/projects/music/COMP/still_life/new_architecture/mashel_falls/st6.WAV"
b = Buffer.read(s, ~path);
b.play;
~size = 2048;
(
SynthDef(\brickwall, {
	var sig, chain, channels=2, size=~size;

	sig = PlayBuf.ar(channels, \buf.kr(0), BufRateScale.ir(\buf.kr(0)), loop: 1);
	chain = FFT.new( LocalBuf(size), sig); // provide buffer for FFT data and signal
	chain = PV_BrickWall(chain, \hpf.kr(20).linlin(20, 20000, 0, 1)); // high pass
	chain = PV_BrickWall(chain, \lpf.kr(20000).linlin(20, 20000, -1, 0)); // low pass

	sig = IFFT(chain);
	sig = Mix.ar(sig);
	sig = Pan2.ar(sig, \pan.kr(0), \amp.kr(0.0));
	Out.ar(\out.kr(0), sig);
}).add;
)


x = Synth(\brickwall);
x.set(\amp, 0.3);
x.set(\pan, -1);

x.set(\hpf, 60, \lpf, 190);
x.set(\hpf, 190, \lpf, 450);
x.set(\hpf, 450, \lpf, 840);
x.set(\hpf, 840, \lpf, 1360);
x.set(\hpf, 1360, \lpf, 2010);
x.set(\hpf, 2010, \lpf, 2790);
x.set(\hpf, 2790, \lpf, 3700);
x.set(\hpf, 3700, \lpf, 4740);

s.boot;
s.quit;


s.meter;



(
~synths = 8.collect( {
	arg synth;
	Synth(\brickwall);
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