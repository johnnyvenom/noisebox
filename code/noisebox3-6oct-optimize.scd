fork{

	~voiceSet = [
		// freqLo, freqHi ratio, mod ratio, mod index 
		[200, 10, 1.3, 10],
		[375, 10, 0.8, 15],
		[400, 20, 2, 3],
		[500, 6, 1.6, 0.6],
		[550, 1.5, 1, 4],
		[666, 3, 1.8, 8],
		[1200, 5, 2, 2],
		[1500, 5, 1.3, 12]
	];
	
	~oscaddr = "/noisebox3";
	~in = [ "/0/0", "/1/0", "/2/0", "/3/0", "/4/0", "/5/0", "/6/0", "/7/0", "/8/0", "/9/0" ];
	~time = 0;
	~last = 0; 

	~maxVoices = 8;
	~voices = Array.fill(~maxVoices);
	n = 0; // voice count - how many voices (count from 1)
	// ~pan = Array.fill(8, 0); // panning positions (-1 to 1)
	~currFreqs = Array.fill(~maxVoices, 0); // keeps track of all the current frequencies
	~accX = 0; // accelerometer x value (roll)
	~accY = 0; // accelerometer y value (pitch)
	~accZ = 0; // accelerometer z value
	
	~voiceSelector = 0; // Use with input /6 (rotary1)
						// 0 == no voices selected (knobs control all voices equally
						// 1 to n == knob controls that voice
						// ToDo: gaussian distribution of parameter control
	~accVal = Array.fill(3, 0);
	
	~muteFlag = 0;
	~muteSens = 0.3; 
	~muteThresh = 2; //how many values above sensitivity at one time to fire trigger; 
	~last = 0; // keeps track of the last accelerometer readings to see if there is a change
	~del = 0.05; // time interval to check accel readings
	t = Array.fill(3, 0); 

	postf("Noisebox v3. 2016. Maximum number of voices is %\n", ~maxVoices);

	SynthDef.new(\fm1, {

		| freq = 55, modPartial = 1, index = 3, 
		  mul = 0.1, lfo = 0.01, gate = 0, pan = 0, amp = 1, out = 0,
		  carFreq = 55, lagTime = 1 |
		
		var mod, car, env, sig;
		env = EnvGen.kr(Env.adsr(3, 5, 0.5, 3), gate: gate, doneAction: 2);

		mod = SinOsc.ar(
			freq * modPartial,
			0,
			freq * index * LFNoise1.kr(lfo)
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

	s.sync;
	"Adding FM synthesizer SynthDef.".post;
	5.do({0.05.wait; " .".post; });
	"\n".postln;

	OSCdef.new(
		\inputs,
		{ | msg, time |
			switch (msg[1].asString)
				{~in[0]}	{~carFrequency.value(msg[2])}	// linearFSR	-> 	pitch control
				{~in[1]}	{~voiceOff.value(msg[2])} 		// buttonLEFT	-> 	turn voices off
				{~in[2]}	{~voiceOn.value(msg[2])} 		// buttonRIGHT	-> 	turn voices on
				{~in[3]}	{~voiceSelect.value(msg[2])} 	// accX (roll) 	-> 	voice selector
				{~in[4]}	{~modIndex.value(msg[2])}		// accY (pitch)	-> 	modulation index
				{~in[5]}	{~modRatio.value(msg[2])}		// accZ (...) 	-> 	modulation ratio
				{~in[6]}	{~glissando.value(msg[2])}		// rotary1 		-> 	
				{~in[7]}	{~lfoSpeed.value(msg[2])}		// rotary2		->
				{~in[8]}	{~tbd1.value(msg[2])}			// rotary3		->
				{~in[9]}	{~tbd2.value(msg[2])};			// rotary4		->

			
			


			//postf("msg: % | time: % | addr: na | port: na\n", msg, time);
			// t = ~time.trunc(0.1);
			// if(t != ~last, {
			//   ~sensVal[9].post; 
			// 	" ".post; 
			// 	~time.postln; 
			// 	~last = t;
			// });
		},
		~oscaddr);

	"OSCdef's initialized, ready to play.".postln;

/***********************
 *   Audio Functions   *
 ***********************/
 
	~voiceOn = { arg inVal; 
		if(inVal == 1,
			{if(n < ~maxVoices, {
				n = n + 1;
				a = ~voiceSet[n-1];
				~voices[n-1] = Synth(\fm1, [\freq, a[0], \carFreq, a[0], \modPartial, a[2], \index, a[3], \gate, 1]);
				~currFreqs[n-1] = a[0];
				~autoPan.value(n); // spread voices across stereo field
				i = n - 1;
				postf("RIGHT button pushed | Current Voice Index: % | Current voice count:  %\n", i, n)},
			{"Maximum polyphony has been reached.".postln;})}
		);
	};

	~voiceOff = { arg inVal; 
		if(inVal == 1,
		{if(n > 0, {
			~voices[n-1].set(\gate, 0);
			n = n - 1;
			~autoPan.value(n);
			postf("LEFT button pushed | Removed voice at index % | New voice count: %\n", n, n)},
		{"All voices are already off.".postln})}
		);
	};
	
	~carFrequency = { arg inVal; 
		if(~voiceSelector == 0, {
			n.do({ | count |
				a = ~voiceSet[count];
				b = inVal.linlin(0, 1, a[0], a[0]*a[1]);
				~voices[count].set(\carFreq, b);
				~currFreqs[count] = b;
			});
		}, 
		{ a = ~voiceSet[~voiceSelector - 1];
			b = inVal.linlin(0, 1, a[0], a[0]*a[1]);
			~voices[~voiceSelector - 1].set(\carFreq, b);
			~currFreqs[~voiceSelector - 1] = b;
		});
	};

	~voiceSelect = { arg inVal; 
		~voiceSelector = inVal.linlin(0.4, 0.6, 0, n).round(1); 
		if(a != ~voiceSelector, {
			if(~voiceSelector == 0, { "Controlling all voices".postln; },
				{ postf("Controlling voice %\n", ~voiceSelector)
			});
			a = ~voiceSelector;
		});
	};

	~modIndex = { arg inVal; 
		if(n > 0, {
		  if(~voiceSelector == 0, {
			  n.do({ | count |
				  a = ~voiceSet[count];
				  ~accY = inVal.linlin(0.4, 0.6, a[3].sqrt, a[3]); // ~accY controls modulation ratio
   			  	  ~voices[count].set(\index, ~accY);
				  // "mod index - all voices: ".post;
				  // ~accY.postln;
			  });
		  }, 
		  { a = ~voiceSet[~voiceSelector - 1];
		  	~accY = inVal.linlin(0.4, 0.6, a[3].sqrt, a[3]); // ~accY controls modulation ratio
		  	~voices[~voiceSelector - 1].set(\index, ~accY);
			// "mod index - voice index: ".post;
			// b = ~voiceSelector - 1;
			// b.post;
			// " ".post;
			//~accY.postln;
		  });
		});
	};

	~modRatio = { arg inVal; 
		if(n > 0, {
		  if(~voiceSelector == 0, {
			  n.do({ | count |
				  a = ~voiceSet[count];
				  ~accZ = inVal.linlin(0.4, 0.6, a[2]*0.9, a[2]); // ~accZ controls modulation ratio
   			  	  ~voices[count].set(\modPartial, ~accZ);
			  });
		  }, 
		  { a = ~voiceSet[~voiceSelector - 1];
		  	~accZ = inVal.linlin(0.4, 0.6, a[2]*0.9, a[2]); // ~accZ controls modulation ratio
		  	~voices[~voiceSelector - 1].set(\modPartial, ~accZ);
		  });
		});
	};
	
	~glissando = { arg inVal; 
		a = inVal.linlin(0, 1, 0.01, 5);
		if(~voiceSelector == 0, {
			n.do({ arg count; 
				~voices[count].set(\lagTime, a)});
			},
			{ ~voice[~voiceSelector].set(\lagTime, a)});	
		postf("% lagTime: %sec\n", ~voiceSelector, a);
	};
	
	~lfoSpeed = { arg inVal; 
		if(~voiceSelector == 0, {
			n.do({ arg count; ~voices[count].set(\lfo, inVal.linlin(0, 1, 0.02, 10))})
		}, 
		{ ~voices[~voiceSelector].set(\lfo, inVal, 0, 1, 0.02, 10) });
	};
	
	~tbd1 = { arg inVal; // reverb control?

		// insert function here
	
	};

	~tbd2 = { arg inVal; // delay control?

		// insert function here
		inVal.postln;
	
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