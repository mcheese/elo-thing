<script>
	import { Navbar, NavBrand, NavLi, NavUl, DarkMode, Tooltip } from 'flowbite-svelte';
	import { GithubSolid } from 'flowbite-svelte-icons';
</script>

<Navbar class="start-0 top-0 z-20 w-full shadow-md">
	<NavBrand href="/">
		<img src="/cheese.png" class="me-3 h-10 rounded-full" alt="..." />
		<span class="self-center whitespace-nowrap text-xl font-semibold dark:text-white"
			>elo thing.</span
		>
	</NavBrand>
	<div class="flex md:order-2">
		<a href="https://github.com/mcheese" class="me-3 self-center"><GithubSolid size="lg" /></a
		><Tooltip>Github</Tooltip>
		<DarkMode class="border dark:border-gray-800" /><Tooltip>Toogle dark mode</Tooltip>
	</div>
	<NavUl>
		<NavLi href="/">Home</NavLi>
		<NavLi href="/xdd">About</NavLi>
		<NavLi href="/xdd">Navbar</NavLi>
		<NavLi href="/xdd">Pricing</NavLi>
		<NavLi href="/xdd">Contact</NavLi>
	</NavUl>
</Navbar>
