<script lang="ts">
  import Standings from '$lib/standings.svelte';
  import Match from '$lib/match.svelte';

  import { page } from '$app/stores';
  import { onMount } from 'svelte';

  let refreshStandings: () => any;
  function onCompletedMatch() {
    refreshStandings();
  }

  let matchid: string | null;
  onMount(() => {
    matchid = $page.url.searchParams.get('id');
  });
</script>

{#if matchid}
  <div class="flex flex-wrap justify-center">
    <div class="max-w-fit" style="width:95vw">
      <Match bind:id={matchid} on:matchCompleted={onCompletedMatch} />
    </div>
    <div class="m-3">
      <Standings bind:id={matchid} bind:refresh={refreshStandings} />
    </div>
  </div>
{/if}
