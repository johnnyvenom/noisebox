s.waitForBoot{
	~voiceSet = [
		[50, 2000, 10, 60, 20, 200],
		[100, 500, 10, 100, 100, 500],
		[500, 2000, 10, 200, 500, 2000],
		[2000, 5000, 2000, 5000, 2000, 5000],
		[5000, 1000, 10, 500, 10, 5000],
		[20, 200, 100, 200, 100, 100],
		[68, 400, 50, 400, 200, 400],
		[1000, 10000, 1000, 10000, 1000, 10000]
	];

	~maxVoices = 8;
	~voices = Array.fill(~maxVoices);
	n = -1; // Voice index
	~voiceCount = 0;
	x = 0;
	y = 0;
	z = 0;

	postf("Maximum number of voices : %\n", ~maxVoices);

	SynthDef.new(\tone, {
		arg freq=40, nharm=12, detune=0.2, gate=0,
		pan=0, amp=1, out=0;
		var sig, env;
		env = EnvGen.kr(Env.adsr(3, 5, 0.5, 3), gate: gate, doneAction: 2);
		sig = Blip.ar(
			freq: freq *
			LFNoise1.kr(0.2!16).bipolar(detune.neg, detune).midiratio,
			numharm: nharm
		);
		sig = sig * LFNoise1.kr(0.5!16).exprange(0.1, 1);
		sig = Splay.ar(sig);
		sig = Balance2.ar(sig[0], sig[1], pan);
		sig = sig * env * amp;
		Out.ar(out, sig);
	}).add;

	SynthDef.new(\fm1, {
		arg freq = 55, carPartial = 1, modPartial = 1, index = 3, mul = 0.05, gate = 0, pan = 0, amp = 1, out = 0;
		var mod, car, env;
		env = EnvGen.kr(Env.adsr(3, 5, 0.5, 3), gate: gate, doneAction: 2);

		mod = SinOsc.ar(
			freq * modPartial,
			0,
			freq * index * LFNoise1.kr(5.reciprocal).abs
		);

		car = SinOsc.ar(
			(freq * carPartial) + mod,
			0,
			mul
		);

		car = Pan2.ar(car, pan);
		Out.ar(out, car);
	}).add;

	s.sync;
	"Synth defined".postln;

	OSCdef.new(
		\button1, // turn voices on
		{
			arg msg, time, addr, port;
			if(msg[1] == 1,
				{if(~voiceCount < ~maxVoices, {
					n = n + 1;
					~voices[n] = Synth(\tone, args: [\freq, ~voiceSet[n][0],\gate, 1]);
					~voiceCount = ~voiceCount + 1;
					~autoPan.value(~voiceCount);
					postf("Button 1 pushed | Current Voice Index: % | Current voice count:  %\n", n, ~voiceCount)},
				{"Maximum polyphony has been reached.".postln;})}
		)},
		'/button1');

	OSCdef.new(
		\button2, // turn voices off
		{
			arg msg, time, addr, port;
			if(msg[1] == 1,
				{if(~voiceCount > 0, {
					~voices[n].set(\gate, 0);
					~voiceCount = ~voiceCount - 1;
					~autoPan.value(~voiceCount);
					postf("Button 2 pushed | Removed voice at index % | New voice count: %\n", n, ~voiceCount);
					n = n - 1},
				{"All voices are already off.".postln})}
		)},
		'/button2');

	OSCdef.new(
		\linear, // linear FSR: frequency
		{ arg msg, time, addr, port;
			if(n >= 0, {
				var freqScaled = msg[1].linexp(0, 1, ~voiceSet[y][0], ~voiceSet[y][1]);
				~voices[y].set(\freq, freqScaled);
				postf("Voice Index [%] frequency set to %Hz\n", n, freqScaled)}
		)},
		'/linear' );

	OSCdef.new(
		\accxyz, // accelerometer positions
		{ arg msg, time, addr, port;
			if(n>=0, {
				y = msg[2].linlin(-1, 1, n, 0).round(1).postln; // y maps to voice selector
				x = msg[1].linlin(-1, 1, -48, 48).postln; // x maps to detune
				~voices[y].set(\detune, x);
			});
		},
		'/accxyz' );

	OSCdef.new(
		\rotary1, // number of harmonics (all voices)
		{arg msg, time, addr, port;
		n+1.do({ arg count; ~voices[count].set(\nharm, msg[1].linlin(0, 1, 0, 48).postln)});
	}, '/rotary1' );

	"OSCdef's initialized, ready to play.".postln;

	/**********************
	 *   Helper Functions  *
	 **********************/

	~autoPan = { arg a;
		a.do({ // Pan all voices
			arg count;
			var panPos, panLin;
			panPos = count + 1 / (~voiceCount + 1);
			// postf("Voice # % out of %. panPos: %\n", count + 1, ~voiceCount, panPos);
			panLin = panPos.linlin(0, 1, -1, 1);
			// postf("Voice # % out of %. panLin: %\n", count + 1, ~voiceCount, panLin);
			~voices[count].set(\pan, panLin)});
	};

}



