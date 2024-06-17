<script>
	import { page } from '$app/stores';
	import logo from '$lib/images/svelte-logo.svg';
	import github from '$lib/images/github.svg';
</script>

<header>
<!-- 	<div class="corner">


	</div>

	<nav>
		<svg viewBox="0 0 2 3" aria-hidden="true">
			<path d="M0,0 L1,2 C1.5,3 1.5,3 2,3 L2,0 Z" />
		</svg>
		<ul>
			<li aria-current={$page.url.pathname === '/' ? 'page' : undefined}>
				<a href="/">Home</a>
			</li>
			<li aria-current={$page.url.pathname === '/about' ? 'page' : undefined}>
				<a href="/about">About</a>
			</li>
		</ul>
		<svg viewBox="0 0 2 3" aria-hidden="true">
			<path d="M0,0 L0,3 C0.5,3 0.5,3 1,2 L2,0 Z" />
		</svg>
	</nav>

	<div class="corner">

	</div>
	-->
</header>

	<directions>
		Click anywhere in the window to start the sound! Clicking will also maximize the window. <br /><br />  
		You can change the air pressure and muscle tension on the vocal cords by moving your mouse! <br /><br/>

		Instructions:<br />
		Changing the syrinx muscle tension affects the pitch and timbre. The lower you move your mouse (you can scroll down) the lower the syrinx muscle tension, and generally, the lower the pitch. The higher your mouse moves, the higher the pitch. In addition, the more to the right that you move your mouse on the screen, the more air pressure below the syrinx and the louder the sound. To stop the sound, move your mouse to the left edge of the screen. Note that each parameter (air pressure, tension) has an effect on pitch, timbre, and volume to some degree. <br /><br />

		This syrinx is based on a computational model of a ring dove syrinx:<br /><br />


		Zaccarelli, R., Elemans, C. P., Fitch, W., & Herzel, H. (2006). Modelling bird songs: voice onset, overtones and registers. Acta acustica united with acustica, 92(5), 741-748.<br /><br />
		Zaccarelli, R. (2009). Mathematical modelling of sound production in birds. <br /><br />
		Elemans, C. P., Zaccarelli, R., & Herzel, H. (2008). Biomechanics and control of vocalization in a non-songbird. Journal of the Royal Society Interface, 5(24), 691-703. <br /><br />

		Parameters of the model were adjusted based on Corythosaurus skeleton and skull, as well as for some speculative properties of its syrinx based on other bird and alligator models. The resonance of the trachea is modeled via waveguide synthesis, and the returning pressure waves are fed back into the model. Skull resonance is not accounted for in this model, as it was developed for the musical dinosaur skull instrument, and in that case, the process happens via the physical recreation of the skull. The muscle tensio parameter in this demonstration combines the parameters for two types of muscle tension that are implemented in the model: (1) transmural pressure difference (the pressure difference between inside and outside the syrinx) and (2) the stress exerted by syringeal muscles (the tracheolateralis) as developed in the Zaccarelli, Elemans, et. al. (2006-9) model for an easier, more intuitive musical interface. <br /><br />
		
		Note: This dinosaur vocalization demonstration is new in-process prototype and software, and the previous computational model based on Fletcher(1998)/Smyth, et. al. (2004) is currently installed in the physical musical instrument (June 2024). <br /><br />
	</directions>

<style>
	header {
		display: flex;
		justify-content: space-between;
	}

	.corner {
		width: 3em;
		height: 3em;
	}

	.corner a {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
	}

	.corner img {
		width: 2em;
		height: 2em;
		object-fit: contain;
	}

	nav {
		display: flex;
		justify-content: center;
		--background: rgba(255, 255, 255, 0.7);
	}

	svg {
		width: 2em;
		height: 3em;
		display: block;
	}

	path {
		fill: var(--background);
	}

	ul {
		position: relative;
		padding: 0;
		margin: 0;
		height: 3em;
		display: flex;
		justify-content: center;
		align-items: center;
		list-style: none;
		background: var(--background);
		background-size: contain;
	}

	li {
		position: relative;
		height: 100%;
	}

	li[aria-current='page']::before {
		--size: 6px;
		content: '';
		width: 0;
		height: 0;
		position: absolute;
		top: 0;
		left: calc(50% - var(--size));
		border: var(--size) solid transparent;
		border-top: var(--size) solid var(--color-theme-1);
	}

	nav a {
		display: flex;
		height: 100%;
		align-items: center;
		padding: 0 0.5rem;
		color: var(--color-text);
		font-weight: 700;
		font-size: 0.8rem;
		text-transform: uppercase;
		letter-spacing: 0.1em;
		text-decoration: none;
		transition: color 0.2s linear;
	}

	a:hover {
		color: var(--color-theme-1);
	}

	directions {
		position: relative;
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		padding: 12px;
	}
</style>
