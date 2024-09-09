<script lang="ts">
  import Standings from '$lib/standings.svelte';
  import Match from '$lib/match.svelte';

  import { page } from '$app/stores';

  let refreshStandings: () => any;
  function onCompletedMatch() {
    refreshStandings();
  }
</script>

<div class="flex flex-wrap justify-center">
  <div class="max-w-fit" style="width:95vw">
    <Match bind:id={$page.params.slug} on:matchCompleted={onCompletedMatch} />
  </div>
  <div class="m-3">
    <Standings bind:id={$page.params.slug} bind:refresh={refreshStandings} />
  </div>
</div>
