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
	
	~oscaddr = "/noisebox3";

	~maxVoices = 8;
	~voices = Array.fill(~maxVoices);
	n = 0; // voice count - how many voices (count from 1)
	p = Array.fill(8, 0); // panning positions (-1 to 1)
	~currFreqs = Array.fill(~maxVoices, 0); // keeps track of all the current frequencies
	~pitch = 0; // accelerometer x value
	~roll = 0; // accelerometer y value
	~yaw = 0; // accelerometer z value
	
	~voiceSelector = 0; // Use with input /6 (rotary1)
						// 0 == no voices selected (knobs control all voices equally
						// 1 to n == knob controls that voice
						// ToDo: gaussian distribution of parameter control
	~accVal = Array.fill(3, 0);
	~muteFlag = 0;
	~muteSens = 0.3; 
	~muteThresh = 2; //how many values above sensitivity at one time to fire trigger; 
	~cycleCounter = 0;

	postf("Noisebox v3. 2016. Maximum number of voices is %\n", ~maxVoices);

	SynthDef.new(\fm1, {

		| freq = 55, modPartial = 1, index = 3, 
		  mul = 0.6, lfo = 0.01, gate = 0, pan = 0, amp = 1, out = 0,
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
	5.do({0.1.wait; " .".post; });
	"\n".postln;

	OSCdef.new(
		\inputs,
		{ | msg, time, addr, port |
			
			case

			// input #0: Linear FSR
			{ msg[1].asString.endsWith("0/0") }	{
				if(~voiceSelector == 0, {
					n.do({ | count |
						a = ~voiceSet[count];
						b = msg[2].linlin(0, 1, a[0], a[0]*a[1]);
						~voices[count].set(\carFreq, b);
						~currFreqs[count] = b;
					});
				}, 
				{ a = ~voiceSet[~voiceSelector - 1];
					b = msg[2].linlin(0, 1, a[0], a[0]*a[1]);
					~voices[~voiceSelector - 1].set(\carFreq, b);
					~currFreqs[~voiceSelector - 1] = b;
				});
			}

			// input #1: button1 - turn voices on
			{ msg[1].asString.endsWith("1/0") }	{
				if(msg[2] ==1,
					{if(n < ~maxVoices, {
						n = n + 1;
						a = ~voiceSet[n-1];
						~voices[n-1] = Synth(\fm1, [\freq, a[0], \carFreq, a[0], \modPartial, a[2], \index, a[3], \gate, 1]);
						~currFreqs[n-1] = a[0];
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
				// msg[2].postln;

				if(n > 0, {
				  if(~voiceSelector == 0, {
					  n.do({ | count |
						  a = ~voiceSet[count];
						  ~pitch = msg[2].linlin(0.4, 0.6, a[2]*0.9, a[2]); // ~pitch controls modulation ratio
		   			  	  ~voices[count].set(\modPartial, ~pitch);
					  });
				  }, 
				  { a = ~voiceSet[~voiceSelector - 1];
				  	~pitch = msg[2].linlin(0.4, 0.6, a[2]*0.9, a[2]); // ~pitch controls modulation ratio
				  	~voices[~voiceSelector - 1].set(\modPartial, ~pitch);
				  });
				});
				
			}


			// input #4: accY - maps to voice selector
			{ msg[1].asString.endsWith("4/0") }	{
				// if(n > 0, {
				// 	~roll = msg[2].linlin(0.4, 0.6, n, 0).round(1); // ~roll maps to voice selector
				// });
				a = ~voiceSelector; 
				~voiceSelector = msg[2].linlin(0.4, 0.6, 0, n).round(1); 
				if(a != ~voiceSelector, {
					postf("Knobs control voice %\n", ~voiceSelector);				
					a = ~voiceSelector;
				});
			}

			
			// input #5: acc PITCH - mod freq ratio 
			{ msg[1].asString.endsWith("5/0") }	{
				//msg[2].postln;
				if(n > 0, {
				  if(~voiceSelector == 0, {
					  n.do({ | count |
						  a = ~voiceSet[count];
						  ~pitch = msg[2].linlin(0.4, 0.6, a[3].sqrt, a[3]); // ~pitch controls modulation ratio
		   			  	  ~voices[count].set(\index, ~pitch);
						  // "mod index - all voices: ".post;
						  // ~pitch.postln;
					  });
				  }, 
				  { a = ~voiceSet[~voiceSelector - 1];
				  	~pitch = msg[2].linlin(0.4, 0.6, a[3].sqrt, a[3]); // ~pitch controls modulation ratio
				  	~voices[~voiceSelector - 1].set(\index, ~pitch);
					// "mod index - voice index: ".post;
					// b = ~voiceSelector - 1;
					// b.post;
					// " ".post;
					//~pitch.postln;
				  });
				});
			}
			

			// input #6: rotary1 - voice selector; 0 = all; 1..n = knobs control that voice
			{ msg[1].asString.endsWith("6/0") }	{				
				//~voiceSelector = msg[2].linlin(0, 1, 0, n).round(1); 
				//postf("Knobs control voice %\n", ~voiceSelector);
			}

			/*
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
			*/
			
			
			// input #8: rotary3 - modulation lfo speed
			{ msg[1].asString.endsWith("8/0") }	{			
					// n.do({ arg count; ~voices[count].set(\lfo, msg[2].linlin(0, 1, 10, 0.02))})
					// }, 
					// { ~voices[~voiceSelector].set(\lfo, msg[2], 0, 1, 10, 0.02) });
			};
			
			/*
			// input #9: rotary4 - modulation index
			{ msg[1].asString.endsWith("9/0") }	{				
				if(~voiceSelector == 0, {
					n.do({ | count |
						a = ~voiceSet[count];
						~voices[count].set(\index, msg[2].linlin(0, 1, a[3], a[3]*a[1]))})
					}, 
					{ ~voice[~voiceSelector].set(\index, msg[2].linlin(0, 1, a[3], a[3]*a[1]))});
			};

			*/
		
			
			// ******** Seismic event *******
			
			switch (msg[1].asString,
			  "/3/0", { ~accVal[0] = msg[2] },
			  "/4/0", { ~accVal[1] = msg[2] },
			  "/5/0", { ~accVal[2] = msg[2] }
			);
			
			if(~cycleCounter % 10000 == 0, {
				postf("/3/0: % | /4/0: % | /5/0: %\n", ~accVal[0], ~accVal[1], ~accVal[2]); 
			});
			
			~accVal.do { arg item;
				// postf("Item = %\n", item, i); 
				if(item.asFloat < ~muteSens, { ~muteFlag = ~muteFlag + 1 });
				if(item.asFloat > (1 - ~muteSens), { ~muteFlag = ~muteFlag + 1 });
			}; 
			
			// ~muteFlag.postln;

			if(~muteFlag >= ~muteThresh, { // if trigger threshold is reached
				if(~mute == 0, { // if ~mute is OFF; mute each voice and set ~mute to ON
					n.do({ arg count; ~voices[count].set(\amp, 0)});
					~mute = 1}, { // else ~mute is ON; unmute each voice and set ~mute back to OFF
					n.do({ arg count; ~voices[count].set(\amp, 1)});
					~mute = 0}
				)}, {~muteFlag = 0 } // if trigger threshold wasnt reached, return flag to 0
			);

		},
		~oscaddr);

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
			postf("Voice # % out of %. panLin: %\n", count + 1, n, panLin);
			~voices[count].set(\pan, panLin); // How to use a line object to smooth pan?
			p[count] = panLin;
		});
	};
}


