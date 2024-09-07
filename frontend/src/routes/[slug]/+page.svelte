<script>
  import Standings from '$lib/standings.svelte';

  import { page } from '$app/stores';
  import { Card } from 'flowbite-svelte';
</script>

<div class="flex flex-wrap justify-center">
  <div class="m-3">
    <Card img="https://i.redd.it/2wttjntmyfhd1.png">
      <p class="mb-3 text-2xl font-bold">xdd</p>
    </Card>
  </div>
  <div class="m-3">
    <Standings bind:id={$page.params.slug} />
  </div>
</div>
