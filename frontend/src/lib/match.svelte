<script lang="ts">
  import { Alert, Card, Button, Progressbar, Spinner } from 'flowbite-svelte';
  import {
    ChevronDoubleLeftOutline,
    ChevronDoubleRightOutline,
    ChevronSortOutline
  } from 'flowbite-svelte-icons';
  import { writable } from 'svelte/store';
  import { onMount } from 'svelte';
  import { PUBLIC_ENDPOINT_URL } from '$env/static/public';

  export let id: string;

  const match_data = writable({});

  let promise = new Promise(() => {});
  function getMatch(sleep: number) {
    promise = (async () => {
      const wait = new Promise((r) => setTimeout(r, sleep));
      const res = await fetch(PUBLIC_ENDPOINT_URL + '/match/' + id);
      if (!res.ok) {
        throw Error(res.status + ' - ' + res.statusText);
      }
      const s = await res.json();
      match_data.set(s);
      await wait;
    })();
  }
  onMount(() => getMatch(0));

  const last_winner = writable('d');
  async function vote(winner: string) {
    const match_id = $match_data.match_id;
    last_winner.set(winner);
    getMatch(1000);
    const res = await fetch(
      PUBLIC_ENDPOINT_URL + '/result?' + new URLSearchParams({ match_id: match_id, result: winner })
    );
    if (!res.ok) {
        throw Error(res.status + ' - ' + res.statusText);
    }
  }
</script>

<div class="flex w-fit max-w-full flex-col">
  <Progressbar class=" m-3 self-center" size="h-4" color="green" />
  <div class="flex flex-row">
    {#await promise}
      <Alert
        color="green"
        class="m-0 h-96 w-screen content-center text-center"
        style="max-width:824px"
      >
        <Spinner color="green" class="mb-12 size-14" />
        {#if $last_winner === 'l'}
          <ChevronDoubleLeftOutline class="mx-auto size-24" />
        {:else if $last_winner === 'r'}
          <ChevronDoubleRightOutline class="mx-auto size-24" />
        {:else}
          <ChevronSortOutline class="mx-auto size-24" />
        {/if}
      </Alert>
    {:then}
      <Card
        on:click={() => vote('l')}
        href="#"
        img="https://www.svgrepo.com/show/508699/landscape-placeholder.svg"
        imgClass="h-52 object-cover"
        class="size-full h-96 w-96 text-right"
      >
        <p class="mt-auto text-lg font-thin">{$match_data.l.rating}</p>
        <p class="mb-3 text-2xl font-bold">{$match_data.l.name}</p>
      </Card>
      <Button on:click={() => vote('d')} color="green" class="mx-2 w-10">Draw</Button>
      <Card
        on:click={() => vote('r')}
        href="#"
        img="https://i.redd.it/2wttjntmyfhd1.png"
        imgClass="h-52 object-cover"
        class="size-full h-96 w-96 text-left"
      >
        <p class="mt-auto text-lg font-thin">{$match_data.r.rating}</p>
        <p class="mb-3 text-2xl font-bold">{$match_data.r.name}</p>
      </Card>
    {:catch err}
      <Alert
        color="red"
        class="m-0 h-96 w-screen content-center text-center"
        style="max-width:824px"
      >
        <h1 class="text-5xl">Error</h1>
        <p class="text-3xl">{err.message}</p>
      </Alert>
    {/await}
  </div>
</div>
