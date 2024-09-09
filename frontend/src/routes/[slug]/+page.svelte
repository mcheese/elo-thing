<script>
  import Standings from '$lib/standings.svelte';
  import Match from '$lib/match.svelte';

  import { page } from '$app/stores';
</script>

<div class="flex flex-wrap justify-center">
  <div class="max-w-fit" style="width:95vw">
    <Match bind:id={$page.params.slug} />
  </div>
  <div class="m-3">
    <Standings bind:id={$page.params.slug} />
  </div>
</div>
