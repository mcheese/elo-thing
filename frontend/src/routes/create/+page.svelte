<script lang="ts">
  import {
    Heading,
    Button,
    ButtonGroup,
    Popover,
    Input,
    Toggle,
    Table,
    TableBody,
    TableBodyCell,
    TableBodyRow,
    Select,
    Modal,
    Spinner,
    Tooltip
  } from 'flowbite-svelte';
  import {
    TrashBinOutline,
    EditOutline,
    PlusOutline,
    CheckOutline,
    CloseOutline,
    ArrowRightOutline,
    ExclamationCircleOutline,
    ClipboardOutline
  } from 'flowbite-svelte-icons';
  import { base } from '$app/paths';
  import { PUBLIC_ENDPOINT_URL } from '$env/static/public';
  import MatchCard from '$lib/matchcard.svelte';
  import Cropper from 'svelte-easy-crop';

  let img_add: string;
  let img_edit: string;
  let list: {
    name: string;
    img: string;
    img_pos?: { x: number; y: number; width: number; height: number } | null;
  }[] = [];
  let hover_row: number;

  function fix_link(link: string) {
    if (!link) return link;
    const regex = new RegExp('^(https?|ftp|data):');
    return regex.test(link) ? link : 'https://' + link;
  }

  function find_dup() {
    const names = new Set();
    const imgs = new Set();
    for (let e of list) {
      if (names.has(e.name)) {
        return 'name: "' + e.name + '"';
      }
      if (e.img) {
        if (imgs.has(e.img)) {
          return 'image: "' + e.img + '"';
        }
        imgs.add(e.img);
      }
      names.add(e.name);
    }
    return '';
  }

  function add(e) {
    if (list.length >= 256) return problem('Too many things.');
    if (!e.target.name.value && !e.target.img_add.value) return problem('Need at least name or image.');

    list = [
      ...list,
      { name: e.target.name.value, img: fix_link(e.target.img_add.value), img_pos: img_pos }
    ];
    e.target.reset();
    img_add = '';
  }

  function remove(i: number) {
    list.splice(i, 1);
    list = list;
  }

  let edit_row: number | null = null;
  function edit(i: number) {
    edit_row = i;
    img_edit = list[i].img;
  }

  function edit_reset() {
    edit_row = null;
    img_edit = '';
    img_pos = null;
  }

  function edit_sub(e) {
    if (edit_row === null) return;
    const name = e.target.querySelector('#name_edit').value;
    const img = e.target.querySelector('#img_edit').value;
    list[edit_row] = { name: name, img: img, img_pos: img_pos ? img_pos : list[edit_row].img_pos };
    edit_reset();
  }

  var img_pos: { x: number; y: number; width: number; height: number } | null;
  function set_crop(e) {
    img_pos = e.detail.pixels;
  }

  let problem_popup = false;
  let problem_text: string;
  function problem(msg: string) {
    problem_text = msg;
    problem_popup = true;
  }

  let confirm_popup = false;
  let duplicate: string;
  function create_list() {
    if (list.length < 2) return problem('Not enough things.');
    if (list.length > 256) return problem('Too many things.');
    duplicate = find_dup();
    confirm_popup = true;
  }

  let submit_promise: Promise<string> | null;
  function submit_list() {
    if (list.length < 2) return problem('Not enough things.');
    if (list.length > 256) return problem('Too many things.');

    const res = fetch(PUBLIC_ENDPOINT_URL + '/create', {
      method: 'POST',
      body: JSON.stringify(list)
    });

    submit_promise = res.then(async (res) => {
      if (!res.ok) {
        problem(
          'There was a problem while creating list.\nServer error: ' +
            res.status +
            ' - ' +
            res.statusText
        );
        throw Error(res.statusText);
      }
      const id = await res.text();
      if (!id.match('/^[A-Za-z0-9_-]{8}$/')) problem('Invalid server response: ' + id);
      return id;
    });
  }
</script>

{#if !submit_promise}
  <div class="mx-auto mt-8 w-screen max-w-screen-xl">
    <Heading tag="h1" class="mb-4 text-center" customSize="text-4xl font-bold">
      Create your own list.
    </Heading>

    <div class="flex w-full flex-wrap justify-center">
      <div class="flex w-full max-w-screen-md flex-col">
        <form on:submit|preventDefault={add} class="w-full">
          <ButtonGroup class="w-full *:!ring-inset">
            <Input type="text" id="name" placeholder="Name" />
            <Input
              type="text"
              id="img_add"
              bind:value={img_add}
              placeholder="Direct link to image"
            />
            <Button color="green" type="submit" class="py-0">
              <PlusOutline class="m-0 size-6" />
            </Button>
          </ButtonGroup>
        </form>
        <form on:submit|preventDefault={(e) => edit_sub(e)}>
          <Table hoverable={true} shadow class="mt-1 table-fixed">
            <TableBody tableBodyClass="divide-y">
              {#each list as el, i}
                <TableBodyRow>
                  {#if edit_row === i}
                    <TableBodyCell class="p-0">
                      <Input type="text" id="name_edit" class="m-0" value={el.name} required />
                    </TableBodyCell>
                    <TableBodyCell class="p-0">
                      <Input type="text" id="img_edit" bind:value={img_edit} class="m-0" />
                    </TableBodyCell>
                    <TableBodyCell class="w-8 p-1">
                      <Button class="m-0 size-7 p-1" color="green" type="submit">
                        <CheckOutline class="size-6" />
                      </Button>
                    </TableBodyCell>
                    <TableBodyCell class="w-8 p-1">
                      <button on:click={edit_reset}>
                        <CloseOutline class="size-6" color="red" />
                      </button>
                    </TableBodyCell>
                  {:else}
                    <TableBodyCell class="p-2">{el.name}</TableBodyCell>
                    <TableBodyCell class="overflow-hidden overflow-ellipsis p-2">
                      <a
                        id="a_img"
                        class="hover:underline"
                        on:mouseenter={() => {
                          hover_row = i;
                        }}
                        target="_blank"
                        href={el.img || ''}
                      >
                        {el.img || ''}
                      </a>
                    </TableBodyCell>
                    <TableBodyCell class="w-8 p-1">
                      <button on:click={() => edit(i)}>
                        <EditOutline class="size-6" />
                      </button>
                    </TableBodyCell>
                    <TableBodyCell class="w-8 p-1">
                      <button on:click={() => remove(i)}>
                        <TrashBinOutline class="size-6" />
                      </button>
                    </TableBodyCell>
                  {/if}
                </TableBodyRow>
              {:else}
                <TableBodyRow>
                  <TableBodyCell class="p-2 text-center"
                    >Add things to the list using the + button.</TableBodyCell
                  >
                </TableBodyRow>
              {/each}
            </TableBody>
          </Table>
        </form>
        <Button color="green" class="mt-1 self-end px-10 py-2" on:click={create_list}>
          <p class="text-lg">Create</p>
        </Button>
      </div>

      <Popover triggeredBy="#img_add" trigger="focus" class="max-w-full shadow-lg">
        <div class="relative h-96 w-96 max-w-full">
          {#if img_add}
            <Cropper
              aspect={96 / 56}
              image={fix_link(img_add)}
              on:cropcomplete={(e) => set_crop(e)}
            />
          {/if}
        </div>
      </Popover>
      {#if edit_row !== null}
        <Popover triggeredBy="#img_edit" trigger="focus" class="max-w-full shadow-lg">
          <div class="relative h-96 w-96 max-w-full">
            <Cropper
              aspect={96 / 56}
              image={fix_link(img_edit)}
              on:cropcomplete={(e) => set_crop(e)}
            />
          </div>
        </Popover>
      {/if}

      {#key list}
        <Tooltip
          placement="bottom-start"
          triggeredBy="#a_img"
          trigger="hover"
          class="max-w-full shadow-lg dark:!bg-gray-900"
        >
          <div class="flex w-full">
            {#key hover_row}
              <MatchCard
                data={{
                  name: list[hover_row].name,
                  rating: 1337,
                  img: list[hover_row].img,
                  img_pos: list[hover_row].img_pos
                }}
                left={false}
                vote={() => {}}
              />
            {/key}
          </div>
        </Tooltip>
      {/key}

      <div class="m-3 w-32 *:*:!-z-10 *:m-2">
        <Toggle color="green">Setting</Toggle>
        <Toggle color="green">Config</Toggle>
        <Toggle color="green">Einstellung</Toggle>
        <Toggle color="green">Option</Toggle>
        <Select
          placeholder="Question"
          class="m-2"
          items={[
            { value: 1, name: 'yes' },
            { value: 2, name: 'no' },
            { value: 3, name: 'maybe' },
            { value: 4, name: "I don't know" },
            { value: 5, name: 'can you repeat the question?' }
          ]}
        />
      </div>
    </div>
  </div>

  <Modal bind:open={problem_popup} size="xs" autoclose>
    <div class="text-center">
      <ExclamationCircleOutline class="mx-auto mb-4 h-12 w-12 text-gray-400 dark:text-gray-200" />
      <h3 class="mb-5 whitespace-pre text-lg font-normal text-gray-500 dark:text-gray-400">
        {problem_text}
      </h3>
      <Button color="alternative">Sorry</Button>
    </div>
  </Modal>

  <Modal bind:open={confirm_popup} size="xs" autoclose>
    <div class="text-center">
      <h3 class="mb-5 text-2xl">Is the list ok?</h3>
      {#if duplicate}
        <p class="my-8 flex flex-row justify-center align-baseline">
          <ExclamationCircleOutline
            class="mx-2 size-6 self-center text-gray-400 dark:text-gray-200"
          />
          Duplicate {duplicate}
        </p>
      {/if}
      <Button color="alternative" class="w-28">Back</Button>
      <Button color="green" class="w-28" on:click={submit_list}>Submit</Button>
    </div>
  </Modal>
{:else}
  {#await submit_promise}
    <div class="flex justify-center">
      <Spinner color="green" class="m-36 size-16" />
    </div>
  {:then id}
    {@const path = base + '/list?id=' + id}
    {@const url = window.location.protocol + '//' + window.location.host + path}
    <div class="m-16 flex flex-col items-center text-center">
      <Heading customSize="text-4xl font-bold">Your list is ready.</Heading>
      <Input readonly value={url} class="m-8 w-96 text-lg" on:focus={(e) => e.target.select()} />

      <div class="flex flex-row justify-center *:m-3">
        <Button
          color="alternative"
          on:click={() => {
            navigator.clipboard.writeText(url);
          }}
        >
          Copy to clipboard
          <ClipboardOutline class="ms-2 h-6 w-6" />
        </Button>
        <Button color="green" href={path}>
          Your list
          <ArrowRightOutline class="ms-2 h-6 w-6" />
        </Button>
      </div>
    </div>
  {:catch}
    {(submit_promise = null)}
  {/await}
{/if}
