<script lang="ts">
  import { Button, Textarea, Listgroup, ListgroupItem, Input } from 'flowbite-svelte';

  export let append: (e) => void;

  function add() {
    list.forEach((el) => {
      append({ name: '', img: domain + el });
    });
  }

  function extractImageLinks(htmlString) {
    // trust in chatgpt
    const imgTagRegex = /<img\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/gi;

    const imageLinks: string[] = [];
    let match;

    while ((match = imgTagRegex.exec(htmlString)) !== null) {
      imageLinks.push(match[1]);
    }

    return imageLinks;
  }

  function fix_link(link: string) {
    if (!link) return link;
    const regex = new RegExp('^(https?|ftp|data):');
    return regex.test(link) ? link : 'https://' + link;
  }

  let domain: string = '';
  let list: string[] = [];
  function update(e) {
    const text = e.target.value;
    list = extractImageLinks(text);
  }
</script>

<div class="flex w-full max-w-full flex-col *:m-1">
  Import embedded images from chunk of HTML code
  <Textarea on:input={update} id="text" placeholder="HTML images" rows="6" name="text" />
  <br />Use domain name as prefix for relative links
  <Input
    on:input={(e) => {
      domain = fix_link(e.target.value);
    }}
    id="text"
    placeholder="Domain name"
    name="domain"
  />

  {#if list.length > 0}
    <Listgroup items={list} let:item>
      <a target="_blank" href="{domain}{item}">{domain}{item}</a>
    </Listgroup>
  {/if}

  <Button class="!mx-0 w-32 self-end" color="green" on:click={add}>Import</Button>
</div>
