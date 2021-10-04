// Eli Fieldsteel: MUS 499C Fall 2018


/*
AMBISONIC FORMAT
encoder for mono, stereo signal -> transformations -> decoder

w, x, y, z
w = mono omni REFERENCE
x, y, z are amp scaled
x = front/back (postive front)
y = left/right (positive left)
z = up/down (positive up)
*/
s.boot;
s.quit;

(
{
	var sig;
	// start with mono signal
	sig = Decay.ar(Dust.ar(20), 0.01, WhiteNoise.ar(0.5));
	// now enocde as b format
	//sig = FoaEncode(sig, FoaEncoderMatrix.newDirection(theta: 0, phi: 0)); // theta in radians: 0 = front center, -pi is counter clockwise, pi is clockwise
	// theta: clockwise circle at 45 degrees: 0, 7pi/4, 3pi/2 (270), 5pi/4, pi (180), 3pi/4, pi/2 (90), pi/4, 0
	// phi: pi/2 directly above, -pi/2 directly below
	sig = FoaEncode.ar(sig, FoaEncoderMatrix.newOmni);
	// transformations happen here




	// decode for speaker setup
	sig = FoaDecode.ar(sig, FoaDecoderMatrix.newStereo( pattern: 0.75)); // hyper-cardiod
	//0 // silence UGen
	Out.ar(0, sig);
}.play;
)


s.meter;
s.quit;


FoaXformDisplay.new(8)
s.plotTree;
s.reboot;
~bus.index;
~bus.free;
~bus = Bus.audio(s, 8);
(
{
	var sig;
	sig = In.ar(~bus, 8);
	sig = FoaDecode.ar(sig, FoaDecoderMatrix.newStereo( pattern: 0.75) );
	Out.ar(0, sig);
}.play
)


// this is essentially what i want, but with my soundbuf players and brickwall filters
(
{
	var sig;
	sig = WhiteNoise.ar(1!8);
	sig = BPF.ar(sig, postln( {exprand(100, 4000)}!8), 0.02); // 8 bandpass filters at random pts 100-8000
	sig = FoaEncode.ar(sig, FoaEncoderMatrix.newDirections(
		(pi, 3pi/4..-3pi/4), // an array of azimuth angles
	));


/*	sig = FoaZoom.ar(
		sig,
		MouseX.kr(0, pi/2).poll,
		//LFSaw.kr(0.5).range(-pi,pi)
	);*/
	sig = FoaPush.ar(
		sig,
		MouseX.kr(0, pi/2).poll,
		LFSaw.kr(0.25).range(-pi, pi)
	);

	sig = FoaDecode.ar(sig, FoaDecoderMatrix.newStereo );
	Out.ar(0, sig * 0.5);
}.play;
)