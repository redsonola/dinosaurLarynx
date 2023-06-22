<script>
	import Header from './Header.svelte';
	import './styles.css';
</script>

<Header /> 


<div class="app">

	<main>
		<slot />
	</main>

	<footer>
		<p><i>Dinosaur Choir</i> is created by Courtney Brown. See the <a href="https://dino.courtney-brown.net/about/">About</a> page for more details.</p>
	</footer>
</div>

<style>
	.app {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
	}

	main {
		flex: 1;
		display: flex;
		flex-direction: column;
		padding: 1rem;
		width: 100%;
		max-width: 64rem;
		margin: 0 auto;
		box-sizing: border-box;
	}

	footer {
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		padding: 12px;
	}

	footer a {
		font-weight: bold;
	}

	@media (min-width: 480px) {
		footer {
			padding: 12px 0;
		}
	}
</style>
