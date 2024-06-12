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
		Use your mouth shape via the webcam to change the tension on the vocal cords!<br /><br />  

		Changing the tension affects the pitch and timbre. The wider the mouth, the higher the tension. <br /> <br />
	In addition, as you accelerate and decelerate your breath whilst blowing into the microphone, you are also driving pitch, timbre, and volume of the sound.<br /> <br />
		
	<!-- <p> <a href="https://vimeo.com/912455205">Click for Video of Demonstration and Instructions for webcam mouth-tracking</a> </p> -->
			
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

	<!--<button on:click={() => setMembraneCount(1)}>Tracheal Syrinx (One Membrane, like an ostrich)</button> 
	<br/><button on:click={() => setMembraneCount(2)}>Tracheobronchial Syrinx (Two Membranes, like a songbird)</button>
	<br/><button on:click={membranesIndependent}>Press for Independent Membranes</button> -->
	<MouthTracking />
<br />
<br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br /><br />

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
