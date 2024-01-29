<script>
	//import Counter from './Counter.svelte';
	import welcome from '$lib/images/svelte-welcome.webp';
	//import welcome_fallback from '$lib/images/svelte-welcome.png';
	import rawr from '$lib/images/Rawr_Study_In_Sonic_Skulls__Courtney_Brown_Sharif_Razzaque__1.png';
	import { trachealSyrinx, setMembraneCount, membranesIndependent } from './dinosaurSyrinx';
	import MouthTracking from './mouthTracking.svelte'; 
	//import Counter from './Counter.svelte';

</script>

<svelte:head>
	<title>Home</title>
	<meta name="description" content="Corythosaurus Syrinx" />
</svelte:head>

<svelte:window on:click={trachealSyrinx} on:touchstart={trachealSyrinx}/>
<div>
<section>
		<directions><p>
		Click anywhere in the window to start the sound and blow into your microphone! <br /><br />  
		You can change the tension on the vocal cords by moving your mouse!<br /><br />  
		Or, use your mouth shape via the webcam to change the tension on the vocal cords!<br /><br />  

		<p>Changing the tension affects the pitch and timbre. The lower you move your mouse (you can scroll down) the lower the tension, and generally, the lower the pitch. The higher your mouse moves, the higher the pitch. Moving the mouse left will also slightly lower the tension, while moving it right will slightly raise it.
	In addition, as you accelerate and decelerate your breath whilst blowing into the microphone, you are also driving pitch, timbre, and volume of the sound.</p>
		
	<p>		Alternatively, enable your webcam and use your mouthshape to control the tension on the vocal cords! The wider and more open your mouth is, the higher the tension. And vice versa.</p>

	<p>The default mode of the computational model employs a two membranes (a tracheobronchial, meaning two membranes, one each in the bronchi) syrinx like a songbird (passerine). However, you can switch between this mode and a tracheal mode with only one membrane (one vibrating membrane in the trachea), like an ostrich, duck, or dove.</p>
	</directions>
	<!-- <h1>

		<span class="dino">
			<picture>
				<img src={rawr} alt="Rawr!" width=75% height=75% />
			</picture>
		</span>
		 

		Dinosaur Choir: Corythosaurus Syrinx
	</h1> -->

	

</section>
</div>

<div class="dinobackground">

	<button on:click={() => setMembraneCount(1)}>Tracheal Syrinx (One Membrane, like an ostrich)</button> 
	<br/><button on:click={() => setMembraneCount(2)}>Tracheobronchial Syrinx (Two Membranes, like a songbird)</button>
	<!-- <br/><button on:click={membranesIndependent}>Press for Independent Membranes</button> -->
	<MouthTracking />


	</div>


<style>


directions {
		position: relative;
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		padding: 12px;
	}
	:global(button) {
    margin:0 auto;
    display:block;
	}

	.dinobackground {
		background: url("https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Corythosaurus_Hendrickx2.jpg/1024px-Corythosaurus_Hendrickx2.jpg");
		background-repeat: no-repeat;
		background-position: center center;  
		background-size:     contain;                      /* <------ */
            /* optional, center the image */
		/* margin: calc(5em + 5%); */
		height: calc( 100vh - 35em );
	}
	section {
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		flex: 0.6;
	}

	h1 {
		width: 100%;
	}

	.dino {
		display: block;
		position: relative; 
		padding: 0 0 0 0;
		width: 100%;
		height: 100%;
	}

	.welcome img {
		position: absolute;
		width: 100%;
		height: 100%;
		top: 0;
		display: block;
	}
</style>
