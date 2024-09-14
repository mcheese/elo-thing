<script lang="ts">
  import { base } from '$app/paths';

  export let data: {
    name: string;
    rating: number;
    img: string;
    img_pos: { x: number; y: number; width: number; height: number } | undefined;
  };

  export let left: boolean;
  export let vote: (winner: string) => void;

  function adjust_image(e: Event) {
    const o = <HTMLImageElement>e.target;
    const scale = o.parentElement.clientWidth / data.img_pos.width;
    o.style.transform =
      'scale(' + scale + ') translate(' + -data.img_pos.x + 'px,' + -data.img_pos.y + 'px)';
  }
</script>

<button
  class="flex size-full h-96 w-96 flex-col overflow-hidden rounded-lg border border-gray-300 bg-white text-gray-500 shadow-md hover:bg-gray-100 dark:border-gray-800 dark:bg-gray-800 dark:text-gray-400 dark:hover:bg-gray-700"
  on:click={() => vote(left ? 'l' : 'r')}
>
  <div class="h-56 w-96 self-center overflow-hidden">
    {#if data.img && data.img_pos}
      <img
        id="img"
        src={data.img}
        alt=""
        class="min-w-fit origin-top-left"
        on:load={adjust_image}
      />
    {:else}
      <img
        id="img"
        src={data.img || base + '/placeholder.png'}
        alt=""
        class="size-full bg-gray-200 object-cover dark:bg-gray-600"
      />
    {/if}
  </div>
  <div class="p-8 flex w-full flex-grow flex-col justify-center text-{left ? 'right' : 'left'}">
    <p class="text-xl font-thin">{data.rating}</p>
    <p class="text-2xl font-bold">{data.name}</p>
  </div>
</button>
