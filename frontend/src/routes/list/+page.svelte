<script lang="ts">
  import Standings from '$lib/standings.svelte';
  import Match from '$lib/match.svelte';

  import { page } from '$app/stores';
  import { error } from '@sveltejs/kit';

  let refreshStandings: () => any;
  function onCompletedMatch() {
    refreshStandings();
  }

  const matchid = $page.url.searchParams.get('id') || error(400, 'no id');
</script>

<div class="flex flex-wrap justify-center">
  <div class="max-w-fit" style="width:95vw">
    <Match id={matchid} on:matchCompleted={onCompletedMatch} />
  </div>
  <div class="m-3">
    <Standings id={matchid} bind:refresh={refreshStandings} />
  </div>
</div>
