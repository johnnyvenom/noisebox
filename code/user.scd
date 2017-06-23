fork{
	~voiceSet = [
		// freqLo, freqHi ratio, 
		[200, 10, 1, 1, 1],
		[375, 10, 1, 1, 1],
		[400, 20, 0.8, 2, 3],
		[500, 6, 1.1, 1.6, 0.6],
		[550, 1.5, 1.5, 1, 4],
		[666, 3, 1.9, 1.8, 8],
		[1200, 5, 5, 2, 2],
		[1500, 5, 0.9, 1.3, 12]
	];
/*	~voiceSet = [
		[100, 500, 1, 1.2, 2],
		[0,0,0,0,0],
		[0,0,0,0,0],
		[0,0,0,0,0],
		[0,0,0,0,0],
		[0,0,0,0,0],
		[0,0,0,0,0],
		[0,0,0,0,0]
	];*/

	~maxVoices = 8;
	~voices = Array.fill(~maxVoices);
	m = -1; // voice index (count from 0)
	n = 0; // voice count - how many voices (count from 1)
	p = Array.fill(8, 0); // panning positions (-1 to 1)
	x = 0; // accelerometer x value
	y = 0; // accelerometer y value
	z = 0; // accelerometer z value
	
	~voiceSelector = 0; // Use with input /6 (rotary1)
						// 0 == no voices selected (knobs control all voices equally
						// 1 to n == knob controls that voice
						// ToDo: gaussian distribution of parameter control
	
	~muteFlag = 0;
	~muteSens = 0.3; 
	~muteThresh = 2; //how many values above sensitivity at one time to fire trigger; 

	postf("Noisebox v3. 2016. Maximum number of voices is %\n", ~maxVoices);

	SynthDef.new(\fm1, {

		| freq = 55, carPartial = 1, modPartial = 1, index = 3, 
		  mul = 0.6, lfo = 0.1, gate = 0, pan = 0, amp = 1, out = 0,
		  carFreq = 55, lagTime = 0.2 |
		
		var mod, car, env, sig;
		env = EnvGen.kr(Env.adsr(3, 5, 0.5, 3), gate: gate, doneAction: 2);

		mod = SinOsc.ar(
			freq * modPartial,
			0,
			freq * index * LFNoise1.kr(lfo.reciprocal).abs
		);

		car = SinOsc.ar(
			(carFreq.lag(lagTime) * carPartial) + mod,
			0,
			mul
		);

		sig = Pan2.ar(car, pan);
		sig = sig * env * amp;
		Out.ar(out, sig);
	}).add;

	s.sync;
	"Adding FM synthesizer SynthDef.".post;
	5.do({0.1.wait; " .".post; });
	"\n".postln;

	OSCdef.new(
		\inputs,
		{ | msg, time, addr, port |
			
			case

			// input #0: Linear FSR
			{ msg[1].asString.endsWith("0/0") }	{
				if(n > 0, {
					a = ~voiceSet[y];
					b = a[0]*a[1];
					c = msg[2].linexp(0, 1, a[0], b);
					~voices[y].set(\carFreq, c);
					// postf("Voice Index [%] frequency set to %Hz\n", n, c)}
				});
			}

			// input #1: button1 - turn voices on
			{ msg[1].asString.endsWith("1/0") }	{
				if(msg[2] ==1,
					{if(n < ~maxVoices, {
						n = n + 1;
						a = ~voiceSet[n-1];
						~voices[n-1] = Synth(\fm1, [\freq, a[0], \carFreq, a[0], \carPartial, a[2], \modPartial, a[3], \index, a[4], \gate, 1]);
						~autoPan.value(n); // spread voices across stereo field
						i = n - 1;
						postf("Button 1 pushed | Current Voice Index: % | Current voice count:  %\n", i, n)},
					{"Maximum polyphony has been reached.".postln;})}
				);
			}

			// input #2: button2	
			{ msg[1].asString.endsWith("2/0") }	{
				if(msg[2] == 1,
				{if(n > 0, {
					~voices[n-1].set(\gate, 0);
					n = n - 1;
					~autoPan.value(n);
					postf("Button 2 pushed | Removed voice at index % | New voice count: %\n", n, n)},
				{"All voices are already off.".postln})}
				);
			}

			// input #3: acc - empty for the moment
			{ msg[1].asString.endsWith("3/0") }	{
				// do something!
				// tbd... 
			}

			// input #4: accY - maps to voice selector
			{ msg[1].asString.endsWith("4/0") }	{
				if(n > 0, {
					y = msg[2].linlin(0.4, 0.6, n, 0).round(1); // y maps to voice selector
				});
			}

			/*
			// input #5: accX - mod freq ratio 
			{ msg[1].asString.endsWith("5/0") }	{
				if(n > 0, {
					a = ~voiceSet[y];
					b = a[3]*a[1];
					x = msg[2].linlin(0.4, 0.6, a[3], b); // x mod frequency ratio
					~voices[y].set(\modPartial, x);
				});
			}
			*/

			// input #6: rotary1 - voice selector; 0 = all; 1..n = knobs control that voice
			{ msg[1].asString.endsWith("6/0") }	{				
				~voiceSelector = msg[2].linlin(0, 1, 0, n).round(1); 
				// postf("Knobs control voice %\n", ~voiceSelector);
			}

			// input #7: rotary2 - 
			{ msg[1].asString.endsWith("7/0") }	{
				a = msg[2].linlin(0, 1, 0.01, 5);
				if(~voiceSelector == 0, {
					n.do({ |count| 
						~voices[count].set(\lagTime, a)})
					},
					{ ~voice[~voiceSelector].set(\lagTime, a)});	
				postf("% lagTime: %sec\n", msg[1], a);
			}
			

			// input #8: rotary3 - modulation lfo speed
			{ msg[1].asString.endsWith("8/0") }	{			
				if(~voiceSelector == 0, {
					n.do({ arg count; ~voices[count].set(\carFreq, msg[2].linlin(0, 1, 200, 2000))})
					}, 
					{ ~voices[~voiceSelector].set(\carFreq, msg[2], 0, 1, 200, 2000) });
					/*
					n.do({ arg count; ~voices[count].set(\lfo, msg[2].linlin(0, 1, 10, 0.02))})
					}, 
					{ ~voices[~voiceSelector].set(\lfo, msg[2], 0, 1, 10, 0.02) });
					*/
			}
			
			/*
			// input #9: rotary4 - modulation index
			{ msg[1].asString.endsWith("9/0") }	{				
				if(~voiceSelector == 0, {
					n.do({ | count |
						a = ~voiceSet[count];
						~voices[count].set(\index, msg[2].linlin(0, 1, a[4], a[4]*a[1]))})
					}, 
					{ ~voice[~voiceSelector].set(\index, msg[2].linlin(0, 1, a[4], a[4]*a[1]))});
			};
			*/
			
			/* FIX THIS...
			// ******** Seismic event *******
			var accVal;
			
			accVal = Array.fill(3); 

			switch (msg[1].asString,
			  "3.0", { accVal[0] = msg[2] },
			  "4.0", { accVal[1] = msg[2] },
			  "5.0", { accVal[2] = msg[2] }
			);
			accVal.do {|item, i|
				if(item < ~muteSense, { ~muteFlag = ~muteFlag + 1 });
				if(item > 1 - ~muteSense, { ~muteFlag = ~muteFlag + 1 });
			}
			if(~muteFlag >= ~muteThresh, {
				if(~mute == 0, {
					n.do({ arg count; ~voices[count].set(\amp, 0)});
					~mute = 1}, {
					n.do({ arg count; ~voices[count].set(\amp, 1)});
					~mute = 0}
				)}, {~muteFlag = 0}
			);
			
			*/
		},
		'/noisebox1');

		"OSCdef's initialized, ready to play.".postln;

	/**********************
	 *   Helper Functions  *
	 **********************/

	~autoPan = { arg a;
		a.do({ // Pan all voices
			arg count;
			var panPos, panLin;
			panPos = count + 1 / (n + 1);
			// postf("Voice # % out of %. panPos: %\n", count + 1, ~voiceCount, panPos);
			panLin = panPos.linlin(0, 1, -1, 1);
			postf("Voice # % out of %. panLin: %\n", count + 1, ~voiceCount, panLin);
			~voices[count].set(\pan, panLin); // How to use a line object to smooth pan?
			p[count] = panLin;
		});
	};
}


