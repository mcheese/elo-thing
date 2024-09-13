<script lang="ts">
  import Standings from '$lib/standings.svelte';
  import Match from '$lib/match.svelte';

  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { error } from '@sveltejs/kit';

  let refreshStandings: () => any;
  function onCompletedMatch() {
    refreshStandings();
  }

  let matchid: string;
  onMount(() => {
    matchid = $page.url.searchParams.get('id') || error(400, 'no id');
  });
</script>

{#if matchid}
  <div class="flex flex-wrap justify-center">
    <div class="max-w-fit" style="width:95vw">
      <Match id={matchid} on:matchCompleted={onCompletedMatch} />
    </div>
    <div class="m-3">
      <Standings id={matchid} bind:refresh={refreshStandings} />
    </div>
  </div>
{/if}
