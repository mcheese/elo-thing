<script>
  import '../app.css';
  import Header from '$lib/header.svelte';
</script>

<Header />
<div class="mx-auto my-3 h-screen max-w-screen-xl">
  <slot />
</div>
