<script>
	import Counter from './Counter.svelte';
	import welcome from '$lib/images/svelte-welcome.webp';
	import welcome_fallback from '$lib/images/svelte-welcome.png';
	import rawr from '$lib/images/Rawr_Study_In_Sonic_Skulls__Courtney_Brown_Sharif_Razzaque__1.png';

</script>

<svelte:head>
	<title>Home</title>
	<meta name="description" content="Corythosaurus Syrinx" />
</svelte:head>

<section>
	<h1>

		<span class="dino">
			<picture>
				<!-- <source srcset={welcome} type="image/webp" /> -->
				<img src={rawr} alt="Rawr!" width=75% height=75% />
			</picture>
		</span>
		 

		Dinosaur Choir: Corythosaurus Syrinx
	</h1>

	<h2>
		Click the button below to start the sound and blow into the microphone! <br />  <br />
	</h2>
	<Counter />
	<br /> <br /> <br /> <br />
	<h2>You can change the tension on the vocal cords by moving your mouse! (HINT: This changes the pitch!)</h2>

</section>

<style>
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
