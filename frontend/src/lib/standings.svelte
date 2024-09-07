<script lang="ts">
  import {
    Table,
    TableBody,
    TableBodyCell,
    TableBodyRow,
    TableHead,
    TableHeadCell
  } from 'flowbite-svelte';
  import { ChevronSortOutline, ChevronDownOutline, ChevronUpOutline } from 'flowbite-svelte-icons';
  import { writable } from 'svelte/store';
  import { onMount } from 'svelte';
  import { PUBLIC_ENDPOINT_URL } from '$env/static/public';

  export let id: string;

  async function getStandings() {
    const res = await fetch(PUBLIC_ENDPOINT_URL + '/standings/' + id);
    if (!res.ok) {
      throw res.statusText;
    }
    return await res.json();
  }

  const sortKey = writable('rank'); // default sort key
  const sortDirection = writable(1); // default sort direction (ascending)
  const sortItems = writable([]);

  let promise = new Promise(() => {});
  onMount(() => {
    promise = (async () => {
      const s = await getStandings();
      sortItems.set(s);
    })();
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
</script>

<Table hoverable={true} shadow>
  <TableHead>
    <TableHeadCell on:click={() => sortTable('rank')}>
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
    <TableHeadCell on:click={() => sortTable('name')}>
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
    <TableHeadCell on:click={() => sortTable('rating')}
      ><span class="flex">
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
  {#await promise then}
    <TableBody tableBodyClass="divide-y">
      {#each $sortItems as s}
        <TableBodyRow>
          <TableBodyCell>{s.rank}</TableBodyCell>
          <TableBodyCell>{s.name}</TableBodyCell>
          <TableBodyCell>{s.rating}</TableBodyCell>
        </TableBodyRow>
      {/each}
    </TableBody>
  {:catch err}
    <p class="m-3 font-mono text-red-600">> Error: {err}</p>
  {/await}
</Table>
