<script>
	import Counter from './Counter.svelte';
	import welcome from '$lib/images/svelte-welcome.webp';
	import welcome_fallback from '$lib/images/svelte-welcome.png';
	import rawr from '$lib/images/Rawr_Study_In_Sonic_Skulls__Courtney_Brown_Sharif_Razzaque__1.png';
	import { trachealSyrinx } from './dinosaurSyrinx';

</script>

<svelte:head>
	<title>Home</title>
	<meta name="description" content="Corythosaurus Syrinx" />
</svelte:head>

<svelte:window on:click={trachealSyrinx} on:touchstart={trachealSyrinx}/>

<section>
	<!-- <h1>

		<span class="dino">
			<picture>
				<img src={rawr} alt="Rawr!" width=75% height=75% />
			</picture>
		</span>
		 

		Dinosaur Choir: Corythosaurus Syrinx
	</h1> -->
	<img width="1024" alt="Corythosaurus Hendrickx2" src="https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Corythosaurus_Hendrickx2.jpg/1024px-Corythosaurus_Hendrickx2.jpg" />


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
