<script lang="ts">
  import { Alert, Card, Button, Progressbar, Spinner } from 'flowbite-svelte';
  import {
    ChevronDoubleLeftOutline,
    ChevronDoubleRightOutline,
    ChevronSortOutline
  } from 'flowbite-svelte-icons';
  import { writable } from 'svelte/store';
  import { onMount, createEventDispatcher } from 'svelte';
  import { PUBLIC_ENDPOINT_URL } from '$env/static/public';

  export let id: string;

  const dispatch = createEventDispatcher();
  function notifyComplete() {
    dispatch('matchCompleted', null);
  }

  const match_data = writable({});

  let promise = new Promise(() => {});

  onMount(() => {
    promise = fetchMatch();
  });

  const last_winner = writable('d');
  const rating_change = writable({});

  async function fetchMatch() {
    const res = await fetch(PUBLIC_ENDPOINT_URL + '/match/' + id);
    if (!res.ok) {
      throw Error(res.status + ' - ' + res.statusText);
    }
    const s = await res.json();
    match_data.set(s);
  }

  function vote(winner: string) {
    promise = (async () => {
      const wait = new Promise((r) => setTimeout(r, 1000)); // min time the match result shows
      last_winner.set(winner);
      rating_change.set({});
      const res = await fetch(
        PUBLIC_ENDPOINT_URL +
          '/result?' +
          new URLSearchParams({ match_id: $match_data.match_id, result: winner })
      );
      if (!res.ok) {
        throw Error(res.status + ' - ' + res.statusText);
      }
      const s = await res.json();
      rating_change.set(s);
      notifyComplete();
      fetchMatch();
      await wait;
    })();
  }

  function numColor(num: number) {
    return num ? (num < 0 ? 'text-red-700' : 'text-lime-600') : 'text-gray-500';
  }
  function numText(num: number) {
    return num == undefined ? '' : num > 0 ? '+' + num : num;
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
        <!--<Spinner color="green" class="mb-12 size-14" /> -->
        <div class="flex flex-row justify-evenly">
          <p class="mt-6 w-12 text-5xl font-bold {numColor($rating_change.l_change)}">
            {numText($rating_change.l_change)}
          </p>
          {#if $last_winner === 'l'}
            <ChevronDoubleLeftOutline class="size-24" />
          {:else if $last_winner === 'r'}
            <ChevronDoubleRightOutline class="size-24" />
          {:else}
            <ChevronSortOutline class="size-24" />
          {/if}
          <p class="mt-6 w-12 text-5xl font-bold {numColor($rating_change.r_change)}">
            {numText($rating_change.r_change)}
          </p>
        </div>
      </Alert>
    {:then}
      <Card
        on:click={() => vote('l')}
        href="#"
        img={$match_data.l.img || '/placeholder.png'}
        imgClass="h-52 object-cover bg-gray-200 dark:bg-gray-600"
        class="size-full h-96 w-96"
      >
        <div class="mt-5 text-right">
          <p class="text-xl font-thin">{$match_data.l.rating}</p>
          <p class="text-2xl font-bold">{$match_data.l.name}</p>
        </div>
      </Card>
      <Button on:click={() => vote('d')} color="green" class="mx-2 w-10">Draw</Button>
      <Card
        on:click={() => vote('r')}
        href="#"
        img={$match_data.r.img || '/placeholder.png'}
        imgClass="h-52 object-cover bg-gray-200 dark:bg-gray-600"
        class="size-full h-96 w-96 text-left"
      >
        <div class="mt-5 text-left">
          <p class="text-xl font-thin">{$match_data.r.rating}</p>
          <p class="text-2xl font-bold">{$match_data.r.name}</p>
        </div>
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
