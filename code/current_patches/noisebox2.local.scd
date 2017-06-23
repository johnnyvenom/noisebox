fork{

	~voiceSet = [
		// freqLo, octave range, mod ratio, mod index 
		[100, 2, 1.5, 2],
		[200, 2, 1.5, 2.2],
		[300, 2, 1.5, 2.4],
		[400, 2, 1.5, 2.6],
		[500, 2, 1.5, 2.8],
		[600, 2, 1.5, 3],
		[700, 2, 1.5, 3.2],
		[800, 2, 1.5, 3.4]
	];
	
	~oscaddr = "/noisebox2";
	~in = [ "/0/0", "/1/0", "/2/0", "/3/0", "/4/0", "/5/0", "/6/0", "/7/0", "/8/0", "/9/0" ];
	
	~maxVoices = 8;
	~voices = Array.fill(~maxVoices, 0);
	n = 0; // voice count - how many voices (count from 1)
	~lag = 0.1; 
	~currFreqs = Array.fill(~maxVoices, 0); // keeps track of all the current frequencies
	~acVal = Array.fill(3, 0); // store incoming X/Y/Z values in an array. 
	
	~voiceSelector = 0; // Use with input /6 (rotary1)
						// 0 == no voices selected (knobs control all voices equally
						// 1 to n == knob controls that voice
						// ToDo: gaussian distribution of parameter control

	// Seismic event vars
	~del = 0.01; // time interval to check accel readings
	~trigFlag = 0; // turns to one when trigger is fired
	~trigTimeout = 0.4; // wait to read trigger signal again (debounce)
	~mute = 0; 
	~trigSens = 0.2; 
	
	~verbMix = 0.4; 
	~verbSize = 0.3; 
	~verbDamp = 0.5; 

	postf("Noisebox v3. 2016. Maximum number of voices is %\n", ~maxVoices);

	SynthDef.new(\fm1, {

		| freq = 55, modPartial = 1, index = 3, 
		  mul = 1, lfo = 0.05, gate = 0, pan = 0, amp = 1, out = 0,
		  carFreq = 55, lagTime = 0.1 |
		
		var mod, car, env, sig;
		env = EnvGen.kr(Env.adsr(lagTime, 5, 1.0, lagTime), gate: gate, doneAction: 2);

		mod = SinOsc.ar(
			carFreq.lag(lagTime) * modPartial.lag(lagTime),
			0,
			carFreq.lag(lagTime) * index.lag(lagTime) * (SinOsc.kr(lfo).abs/4+0.75)
		);

		car = SinOsc.ar(
			carFreq.lag(lagTime) + mod,
			0,
			mul
		);

		sig = Pan2.ar(car, pan);
		sig = sig * env * amp;
		Out.ar(out, sig);
	}).add;
	
	SynthDef(\verb, {|outbus, mix = 0.40, room = 0.3, damp = 0.5, amp = 1.0|
    	var signal;
    	signal = In.ar(outbus, 2);
   		ReplaceOut.ar(outbus,
  	    	FreeVerb2.ar( // FreeVerb2 - true stereo UGen
            	signal[0], // Left channel
        	    signal[1], // Right Channel
    	        mix, room, damp, amp)); // same params as FreeVerb 1 chn version
	}).add;
	
	d = Buffer.alloc(s, 44100 * 2, 2); 
	
	SynthDef(\delay, {|outrev = 0, bufnum = 0, delTime = 0.1, delFeedback = 0 |
		var signal; 
		
		signal = In.ar(outrev, 2); 
		ReplaceOut.ar(outrev, 
			PingPong.ar(bufnum, [signal[0], signal[1]], delTime.lag(0.5), delFeedback));
	}).add; 

	s.sync;
	"Adding synths.".post;
	5.do({0.05.wait; " .".post; });
	"\n".postln;
	
	y = Synth(\delay, [\outrev, 0], addAction: \addToTail);
	z = Synth(\verb, [\outbus, 0], addAction: \addToTail);

	OSCdef.new(
		\inputs,
		{ | msg, time |
			switch (msg[1].asString)
				{~in[0]}	{~carFrequency.value(msg[2])}	// linearFSR	-> 	pitch control
				{~in[1]}	{~voiceOff.value(msg[2])} 		// buttonLEFT	-> 	turn voices off
				{~in[2]}	{~voiceOn.value(msg[2])} 		// buttonRIGHT	-> 	turn voices on
//				{~in[3]}	{~voiceSelect.value(msg[2])}	// accX (roll) 	-> 	voice selector
				{~in[3]}	{~glissando.value(msg[2])}	// accX (roll) 	-> 	glissando
				{~in[4]}	{~modIndex.value(msg[2])}		// accY (pitch)	-> 	modulation index
				{~in[5]}	{~modRatio.value(msg[2])}		// accZ (...) 	-> 	modulation ratio
//				{~in[6]}	{~glissando.value(msg[2])}		// rotary1 		-> 	
//				{~in[6]}	{~delayTime.value(msg[2])}		// rotary1 		-> 	
//				{~in[7]}	{~delayFeedback.value(msg[2])}	// rotary2		->
//				{~in[8]}	{~reverbSize.value(msg[2])}		// rotary3		->
//				{~in[9]}	{~reverbMix.value(msg[2])};		// rotary4		->

		},
		~oscaddr);

	"OSCdef's initialized, ready to play.".postln;

	Routine.run({

		"Waiting 3 sec to start".postln; 
		3.wait; 
		"Started; checking for trigger.".postln;

		inf.do{ //infinitely do...
			var flags = Array.fill(3, 0); 
 
			~acVal.do{ arg item, i; 
				flags[i] = abs(item - 0.5); 
			};
			~del.wait;
			
			// postf("x: % | y: % | z: % |flags.sum = %\n", flags[0], flags[1], flags[2], flags.sum);
			
			if(flags.sum > ~trigSens, {
				if(~trigFlag == 0, { 
					"TRIGGER EVENT".postln; 
					~trigFlag = 1;
					switch(~mute) // 0 voices are on; 1 voices are muted
						{0} { n.do{ | count | 
								~voices[count].set(\amp, 0); 
								~mute = 1; }
							} 
						{1} { n.do{ | count | 
								~voices[count].set(\amp, 1); 
								~mute = 0; }
							};
				});// mute voices
			}, {  
				~trigTimeout.wait; 
				//"mute flag reset to 0".postln; 
				~trigFlag = 0; 
			}); 
		};
		
	});

	

/***********************
 *   Audio Functions   *
 ***********************/
 
	~voiceOn = { |inVal| 
		if(inVal == 1,
			{if(n < ~maxVoices, {
				n = n + 1;
				a = ~voiceSet[n-1];
				~voices[n-1] = Synth(\fm1, [\freq, a[0], \carFreq, a[0], \modPartial, a[2], \index, a[3], \lagTime, ~lag, \gate, 1]);
				~currFreqs[n-1] = a[0];
				~autoPan.value(n); // spread voices across stereo field
				i = n - 1;
				postf("RIGHT button pushed | Current Voice Index: % | Current voice count:  %\n", i, n)},
			{"Maximum polyphony has been reached.".postln;})}
		);
	};

	~voiceOff = { |inVal|
		if(inVal == 1,
		{if(n > 0, {
			~voices[n-1].set(\gate, 0);
			n = n - 1;
			~autoPan.value(n);
			postf("LEFT button pushed | Removed voice index % | New voice count: %\n", n, n)},
		{"All voices are already off.".postln})}
		);
	};
	
	~carFrequency = { |inVal|
		//inVal.expexp(0.01, 1, 110, 1760).postln;
		if(~voiceSelector == 0, {
			n.do({ | count |
				a = ~voiceSet[count];
				b = inVal.explin(0.02, 1, a[0], a[0]*2.pow(a[1]));
				~voices[count].set(\carFreq, b);
				~currFreqs[count] = b;
			});
		}, 
		{ a = ~voiceSet[~voiceSelector - 1];
			b = inVal.explin(0.02, 1, a[0], a[0]*2.pow(a[1]));
			~voices[~voiceSelector - 1].set(\carFreq, b);
			~currFreqs[~voiceSelector - 1] = b;
		});
	};

	~voiceSelect = { |inVal|
		~acVal[0] = inVal;
		a = inVal.linlin(0.4, 0.6, 0, n).round(1);
		~voiceSelector = a; 
		// ~voiceSelector = ~acVal[0].linlin(0.4, 0.6, 0, n).round(1); 
		/*
		if(a != ~voiceSelector, {
			if(~voiceSelector == 0, { "Controlling all voices".postln; },
				{ postf("Controlling voice %\n", ~voiceSelector)
			});
			a = ~voiceSelector;
		});
		*/
	};

	~modIndex = { |inVal| 
		~acVal[1] = inVal; 
		if(n > 0, {
		  if(~voiceSelector == 0, {
			  n.do({ | count |
				  a = ~voiceSet[count];
   			  	  ~voices[count].set(\index, inVal.linlin(0.4, 0.6, a[3].log, a[3].exp));
				  // "mod index - all voices: ".post;
				  // ~accY.postln;
				  //inVal.linlin(0.4, 0.6, a[3].log, a[3].exp).postln;
			  });
		  }, 
		  { a = ~voiceSet[~voiceSelector - 1];
		  	~voices[~voiceSelector - 1].set(\index, inVal.linlin(0.4, 0.6, a[3].log, a[3].exp));
			//inVal.linlin(0.4, 0.6, a[3].log, a[3].exp).postln;
		  });
		});
	};

	~modRatio = { |inVal| 
		~acVal[2] = inVal; 
		if(n > 0, {
		  if(~voiceSelector == 0, {
			  n.do({ | count |
				  a = ~voiceSet[count];
   			  	  ~voices[count].set(\modPartial, inVal.linlin(0.4, 0.6, a[2]/2, a[2]*2));
			  });
		  }, 
		  { a = ~voiceSet[~voiceSelector - 1];
		  	~voices[~voiceSelector - 1].set(\modPartial, inVal.linlin(0.4, 0.6, a[2]/2, a[2]*2));
		  });
		});
	};
	
	~glissando = { |inVal|
		~acVal[0] = inVal;
		~lag = abs(inVal - 0.5); 
		~lag = ~lag.linlin(0.01, 0.1, 0.03, 5);
		// ~lag.postln;
		if(n > 0, {
			if(~voiceSelector == 0, {
				n.do({ | count | 
					~voices[count].set(\lagTime, ~lag)});
			}, {
				~voices[~voiceSelector - 1].set(\lagTime, ~lag)
			});	
			// postf("% lagTime: %sec\n", ~voiceSelector, a);
		}); 
	};
	
	
	~lfoSpeed = { |inVal| 
		if(~voiceSelector == 0, {
			n.do({ arg count; ~voices[count].set(\lfo, inVal.linlin(0, 1, 0.02, 10))})
		}, 
		{ ~voices[~voiceSelector - 1].set(\lfo, inVal.linlin(0, 1, 0.02, 10))});
	};
	
	~reverbMix = { |inVal| // reverb control?
		~verbMix = inVal;
		z.set(\mix, ~verbMix);
	};

	~reverbSize = { |inVal| // delay control?
		~verbSize = inVal;
		z.set(\room, ~verbSize);
	};

	~reverbDamp = { |inVal| // delay control?
		~verbDamp = inVal;
		z.set(\damp, ~verbDamp);
	};
	
	
	~delayTime = { |inVal| 
		y.set(\delTime, inVal.clip(0.01, 1).linlin(0.01, 1, 0.1, 4));
	};
	
	~delayFeedback = { |inVal|
		y.set(\delFeedback, inVal.linlin(0, 1, 0, 0.98));
	};
	
	
/***********************
 *   Helper Functions  *
 ***********************/
	
	~autoPan = { arg a;
		a.do({ // Pan all voices
			arg count;
			var panPos, panLin;
			panPos = count + 1 / (n + 1);
			// postf("Voice # % out of %. panPos: %\n", count + 1, ~voiceCount, panPos);
			panLin = panPos.linlin(0, 1, -1, 1);
			postf("Voice # % out of %. panLin: %\n", count + 1, n, panLin);
			~voices[count].set(\pan, panLin); // How to use a line object to smooth pan?
			// ~pan[count] = panLin;
		});
	};

}