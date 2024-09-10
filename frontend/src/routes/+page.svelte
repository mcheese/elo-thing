<script>
  import { Heading, P, Button, Popover } from 'flowbite-svelte';
  import { ArrowRightOutline } from 'flowbite-svelte-icons';
  import { base } from '$app/paths';
</script>

<div class="mx-auto mt-16 w-screen max-w-screen-xl text-center">
  <Heading tag="h1" class="mb-4" customSize="text-4xl font-bold  md:text-5xl lg:text-6xl">
    [<span class="font-extrabold text-green-500" id="n">Elo thing</span>] is in development
  </Heading>
  <Popover class="text-md" triggeredBy="#n">
  name pending
  </Popover>
  <P class="mb-6 text-lg dark:text-gray-400 sm:px-16 lg:text-xl xl:px-48">
    You are probably not supposed to be here. Stuff is still getting build and there isn't much
    working yet. Maybe check out the testing list, with some luck it could be up.
  </P>
  <Button color="green" href="{base}/list?id=BAAAAAAA">
    Testing List
    <ArrowRightOutline class="ms-2 h-6 w-6" />
  </Button>
</div>
