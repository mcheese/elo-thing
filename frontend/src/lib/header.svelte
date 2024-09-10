<script>
  import { Navbar, NavBrand, NavLi, NavUl, DarkMode, Tooltip } from 'flowbite-svelte';
  import { GithubSolid } from 'flowbite-svelte-icons';
  import { base } from '$app/paths':
</script>

<Navbar let:NavContainer class="start-0 top-0 z-20 w-full shadow-md">
  <NavContainer class="max-w-screen-xl">
    <NavBrand href="{base}/">
      <img src="/cheese.png" class="me-3 h-10 rounded-full" alt="..." />
      <span class="self-center whitespace-nowrap text-xl font-semibold dark:text-white">
        Elo thing.
      </span>
    </NavBrand>

    <NavUl>
      <NavLi href="{base}/">Home</NavLi>
      <NavLi href="{base}/xdd">Create</NavLi>
      <NavLi href="{base}/xdd">About</NavLi>
    </NavUl>

    <div class="flex">
      <a href="https://github.com/mcheese/elo-thing" class="me-3 self-center">
        <GithubSolid size="lg" href="#" />
      </a>
      <Tooltip>Github</Tooltip>

      <DarkMode class="border dark:border-gray-800" />
      <Tooltip>Toogle dark mode</Tooltip>
    </div>
  </NavContainer>
</Navbar>
