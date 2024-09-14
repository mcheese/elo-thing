<script lang="ts">
  import {
    Table,
    TableBody,
    TableBodyCell,
    TableBodyRow,
    TableHead,
    TableHeadCell,
    Spinner
  } from 'flowbite-svelte';
  import { ChevronSortOutline, ChevronDownOutline, ChevronUpOutline } from 'flowbite-svelte-icons';
  import { writable } from 'svelte/store';
  import { onMount } from 'svelte';
  import { base } from '$app/paths';
  import { PUBLIC_ENDPOINT_URL } from '$env/static/public';

  export let id: string;
  export const refresh = () => fetchStandings();

  async function fetchStandings() {
    const res = await fetch(PUBLIC_ENDPOINT_URL + '/group/' + id);
    if (!res.ok) {
      throw Error(res.status + ' - ' + res.statusText);
    }
    const s = await res
      .json()
      .then((j) => {
        return [...j].sort((a, b) => {
          const aVal: number = a['rating'];
          const bVal: number = b['rating'];
          if (aVal < bVal) {
            return 1;
          } else if (aVal > bVal) {
            return -1;
          } else {
            return 0;
          }
        });
      })
      .then((j) => {
        return j.map((v, i) => ({ ...v, rank: i + 1 }));
      });
    sortItems.set(s);
  }

  const sortKey = writable('rank'); // default sort key
  const sortDirection = writable(1); // default sort direction (ascending)
  const sortItems = writable([{}]);

  let promise: Promise<void>;
  onMount(() => {
    promise = fetchStandings();
  });

  // Define a function to sort the items
  const sortTable = (key: string) => {
    // If the same key is clicked, reverse the sort direction
    if ($sortKey === key) {
      sortDirection.update((val) => -val);
    } else {
      sortKey.set(key);
      sortDirection.set(1);
    }
  };

  $: {
    const key = $sortKey;
    const direction = $sortDirection;
    const sorted = [...$sortItems].sort((a, b) => {
      const aVal = a[key];
      const bVal = b[key];
      if (aVal < bVal) {
        return -direction;
      } else if (aVal > bVal) {
        return direction;
      }
      return 0;
    });
    sortItems.set(sorted);
  }

  function adjust_image(e: Event, img_pos) {
    if (typeof img_pos == 'string')
      img_pos = JSON.parse(img_pos);
    const o = <HTMLImageElement>e.target;
    const scale = o.parentElement.clientWidth / img_pos.width;
    o.style.transform =
      'scale(' + scale + ') translate(' + -img_pos.x + 'px,' + -img_pos.y + 'px)';
  }
</script>

<Table hoverable={true} shadow class="w-96">
  <TableHead>
    <TableHeadCell class="pl-1" on:click={() => sortTable('rank')}>
      <span class="flex">
        Rank
        {#if $sortKey === 'rank'}
          {#if $sortDirection === 1}
            <ChevronDownOutline class="h-4" />
          {:else}
            <ChevronUpOutline class="h-4" />
          {/if}
        {:else}
          <ChevronSortOutline class="h-4" />
        {/if}
      </span>
    </TableHeadCell>
    <TableHeadCell class="px-3" on:click={() => sortTable('name')}>
      <span class="flex">
        Name
        {#if $sortKey === 'name'}
          {#if $sortDirection === 1}
            <ChevronDownOutline class="h-4" />
          {:else}
            <ChevronUpOutline class="h-4" />
          {/if}
        {:else}
          <ChevronSortOutline class="h-4" />
        {/if}
      </span>
    </TableHeadCell>
    <TableHeadCell class="px-3">Image</TableHeadCell>
    <TableHeadCell class="px-1" on:click={() => sortTable('rating')}>
      <span class="ml-auto flex w-min">
        Rating
        {#if $sortKey === 'rating'}
          {#if $sortDirection === 1}
            <ChevronDownOutline class="h-4" />
          {:else}
            <ChevronUpOutline class="h-4" />
          {/if}
        {:else}
          <ChevronSortOutline class="h-4" />
        {/if}
      </span>
    </TableHeadCell>
  </TableHead>
  <TableBody tableBodyClass="divide-y">
    {#await promise}
      <TableBodyRow>
        <TableBodyCell colspan="4" class="text-center">
          <Spinner color="green" class="size-8" />
        </TableBodyCell>
      </TableBodyRow>
    {:then}
      {#each $sortItems as s}
        <TableBodyRow>
          <TableBodyCell class="p-3">{s.rank}</TableBodyCell>
          <TableBodyCell class="p-3">{s.name}</TableBodyCell>
          {#if s.img}
            <TableBodyCell class="p-0">
              <div class="w-24 h-14 self-center overflow-hidden">
                {#if s.img_pos}
                  <img
                    id="img"
                    src={s.img}
                    alt=""
                    class="min-w-fit origin-top-left"
                    on:load={(e) => {adjust_image(e, s.img_pos)}}
                  />
                {:else}
                  <img
                    id="img"
                    src={s.img || base + '/placeholder.png'}
                    alt=""
                    class="size-full bg-gray-200 object-cover dark:bg-gray-600"
                  />
                {/if}
              </div>
            </TableBodyCell>
          {:else}
            <TableBodyCell class="p-0" />
          {/if}
          <TableBodyCell class="p-3 text-right">{s.rating}</TableBodyCell>
        </TableBodyRow>
      {/each}
    {:catch err}
      <TableBodyRow>
        <TableBodyCell colspan="4">
          <p class="font-mono text-red-900 dark:text-red-500">> Error: {err.message}</p>
        </TableBodyCell>
      </TableBodyRow>
    {/await}
  </TableBody>
</Table>
