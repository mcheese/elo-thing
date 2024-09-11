<script lang="ts">
  import { Alert, Card, Button, Progressbar, Tooltip } from 'flowbite-svelte';
  import {
    ChevronDoubleLeftOutline,
    ChevronDoubleRightOutline,
    ChevronSortOutline,
    CloseOutline,
  } from 'flowbite-svelte-icons';
  import { writable } from 'svelte/store';
  import { onMount, createEventDispatcher } from 'svelte';
  import { base } from '$app/paths';
  import { PUBLIC_ENDPOINT_URL } from '$env/static/public';

  export let id: string;

  const dispatch = createEventDispatcher();
  function notifyComplete() {
    dispatch('matchCompleted', null);
  }

  interface Thing {
    rating: number;
    name: string;
    img: string;
  }
  const match_data = writable<{ match_id: string; l: Thing; r: Thing }>();

  let promise = new Promise(() => {});

  onMount(() => {
    promise = fetchMatch();
  });

  const last_winner = writable('d');
  const rating = writable<{ l: number | null; r: number | null }>({l:null, r:null});

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
      rating.set({ l: null, r: null });
      const res = await fetch(
        PUBLIC_ENDPOINT_URL +
          '/result?' +
          new URLSearchParams({ match_id: $match_data.match_id, result: winner })
      );
      if (!res.ok) {
        throw Error(res.status + ' - ' + res.statusText);
      }
      const s = await res.json();
      rating.set(s);
      notifyComplete();
      fetchMatch();
      await wait;
    })();
  }

  function numColor(num: number | null) {
    return num ? (num < 0 ? 'text-red-700' : 'text-lime-600') : 'text-gray-500';
  }
  function numText(num: number | null) {
    return num == null ? '' : num > 0 ? '+' + num : num;
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
          <p class="mt-6 w-12 text-5xl font-bold {numColor($rating.l)}">
            {numText($rating.l)}
          </p>
          {#if $last_winner === 'l'}
            <ChevronDoubleLeftOutline class="size-24" />
          {:else if $last_winner === 'r'}
            <ChevronDoubleRightOutline class="size-24" />
          {:else}
            <ChevronSortOutline class="size-24" />
          {/if}
          <p class="mt-6 w-12 text-5xl font-bold {numColor($rating.r)}">
            {numText($rating.r)}
          </p>
        </div>
      </Alert>
    {:then}
      <Card
        on:click={() => vote('l')}
        href="#"
        img={$match_data.l.img || base + '/placeholder.png'}
        imgClass="h-52 object-cover bg-gray-200 dark:bg-gray-600"
        class="size-full h-96 w-96"
      >
        <div class="mt-5 text-right">
          <p class="text-xl font-thin">{$match_data.l.rating}</p>
          <p class="text-2xl font-bold">{$match_data.l.name}</p>
        </div>
      </Card>
      <div class="mx-2 flex w-10 flex-col">
        <Button on:click={() => vote('x')} color="dark" class="w-full h-10"><CloseOutline class="size-8" /></Button>
        <Tooltip>Skip</Tooltip>
        <Button on:click={() => vote('d')} color="green" class="mt-2 w-full flex-grow">Draw</Button>
      </div>
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
