<script>
  import { page } from '$app/stores';
  import { Alert } from 'flowbite-svelte';
</script>

<Alert color="red" class="mx-auto w-screen max-w-screen-sm mt-8 text-center font-mono">
  <h1 class="text-5xl">Error {$page.status}</h1>
  <p class="text-3xl">> {$page.error.message}</p>
</Alert>
