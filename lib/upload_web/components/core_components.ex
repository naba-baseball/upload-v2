defmodule UploadWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: UploadWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices with vintage baseball styling.
  Styled like old stadium announcement boards.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap vintage-card",
        @kind == :info && "border-success bg-success/10",
        @kind == :error && "border-error bg-error/10"
      ]}>
        <.icon
          :if={@kind == :info}
          name="hero-information-circle"
          class="size-5 shrink-0 text-success"
        />
        <.icon
          :if={@kind == :error}
          name="hero-exclamation-circle"
          class="size-5 shrink-0 text-error"
        />
        <div class="font-body">
          <p :if={@title} class="font-display">{@title}</p>
          <p class="text-sm">{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.
  Styled with 1920s vintage baseball aesthetic.

  ## Variants

  - `primary` - Navy blue, main actions (like a team uniform)
  - `success` - Deep green, save/confirm actions
  - `secondary` - Vintage crimson, secondary actions
  - `danger` - Deep red, destructive actions
  - `ghost` - Transparent with subtle hover

  ## Sizes

  - `default` - Standard padding
  - `sm` - Compact padding

  ## Examples

      <.button>Send!</.button>
      <.button variant="primary">Primary Action</.button>
      <.button variant="success" type="submit">Save</.button>
      <.button variant="danger" size="sm">Delete</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :type, :string, default: "button"
  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary success secondary danger ghost), default: "primary"
  attr :size, :string, values: ~w(default sm), default: "default"

  attr :rest, :global,
    include:
      ~w(href navigate patch method download name value disabled form data-confirm phx-click phx-value-*)

  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    base_classes =
      "vintage-btn font-display inline-flex items-center justify-center transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"

    size_classes = %{
      "default" => "px-6 py-3 text-base",
      "sm" => "px-4 py-2 text-sm"
    }

    variant_classes = %{
      "primary" => "vintage-btn-primary",
      "success" => "bg-success border-success text-success-content hover:brightness-110",
      "secondary" => "vintage-btn-secondary",
      "danger" => "bg-error border-error text-error-content hover:brightness-110",
      "ghost" =>
        "bg-transparent border-transparent text-neutral hover:bg-base-200 hover:border-base-300 shadow-none"
    }

    assigns =
      assign(assigns, :computed_class, [
        base_classes,
        Map.fetch!(size_classes, assigns.size),
        Map.fetch!(variant_classes, assigns.variant),
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button type={@type} class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders a card container with vintage baseball styling.
  Like a classic baseball card from the 1920s.

  ## Variants

  - `default` - Vintage cream paper background with primary border
  - `indigo` - Deep navy background (like a night game)
  - `white` - Clean white background
  - `bordered` - Extra prominent border with stitch details

  ## Examples

      <.card>Simple content</.card>
      <.card variant="indigo" hover>Dark stadium card</.card>
      <.card variant="bordered" class="p-8">
        <:header>Card Title</:header>
        Body content here
      </.card>
  """
  attr :id, :string, default: nil
  attr :variant, :string, values: ~w(default indigo white bordered), default: "default"
  attr :hover, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global

  slot :header
  slot :inner_block, required: true
  slot :footer

  def card(assigns) do
    variant_classes = %{
      "default" => "vintage-card shadow-lg",
      "indigo" => "vintage-card bg-primary border-primary text-primary-content shadow-xl",
      "white" => "vintage-card bg-base-100 shadow-md border-primary/30",
      "bordered" => "vintage-card border-4 border-primary/50 shadow-lg"
    }

    hover_classes =
      if assigns.hover do
        "card-hover"
      else
        nil
      end

    assigns =
      assign(assigns, :computed_class, [
        Map.fetch!(variant_classes, assigns.variant),
        hover_classes,
        assigns.class,
        "p-4"
      ])

    ~H"""
    <div id={@id} class={@computed_class} {@rest}>
      <div :if={@header != []} class="mb-6 relative">
        <div class="vintage-ornament mb-4">
          <div class="vintage-ornament-diamond"></div>
        </div>
        {render_slot(@header)}
      </div>
      {render_slot(@inner_block)}
      <div :if={@footer != []} class="mt-6 relative">
        <div class="vintage-ornament mb-4">
          <div class="vintage-ornament-diamond"></div>
        </div>
        {render_slot(@footer)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a back navigation link with a left arrow icon.

  ## Examples

      <.back_link navigate={~p"/dashboard"}>Back to Dashboard</.back_link>
  """
  attr :navigate, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def back_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "inline-flex items-center gap-1 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200",
        @class
      ]}
    >
      <.icon name="hero-arrow-left" class="w-4 h-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders an empty state message with optional icon.

  ## Examples

      <.empty_state>No items found</.empty_state>
      <.empty_state icon="hero-inbox">No messages yet</.empty_state>
  """
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def empty_state(assigns) do
    ~H"""
    <div class={[
      "bg-gray-50 dark:bg-gray-900/50 border border-gray-200 dark:border-gray-700 rounded-lg p-6",
      @class
    ]}>
      <div class="flex items-center gap-3 text-gray-600 dark:text-gray-400">
        <.icon :if={@icon} name={@icon} class="w-6 h-6 shrink-0" />
        <p>{render_slot(@inner_block)}</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders a user avatar image with consistent styling.

  ## Sizes

  - `xs` - 2rem (32px)
  - `sm` - 2rem (32px)
  - `md` - 3rem (48px)
  - `lg` - 4rem (64px)

  ## Examples

      <.user_avatar user={@current_user} />
      <.user_avatar user={@user} size="lg" />
  """
  attr :user, :map, required: true
  attr :size, :string, values: ~w(xs sm md lg), default: "md"
  attr :class, :any, default: nil

  def user_avatar(assigns) do
    size_classes = %{
      "xs" => "w-6 h-6",
      "sm" => "w-8 h-8",
      "md" => "w-12 h-12",
      "lg" => "w-16 h-16"
    }

    assigns = assign(assigns, :size_class, Map.fetch!(size_classes, assigns.size))

    ~H"""
    <img
      :if={@user.avatar_url}
      src={@user.avatar_url}
      alt={@user.name}
      class={[
        "rounded-full ring-2 ring-gray-200 dark:ring-gray-700",
        @size_class,
        @class
      ]}
    />
    """
  end

  @doc """
  Renders a user profile display with avatar and info.

  ## Examples

      <.user_profile user={@current_user} />
      <.user_profile user={@user} show_email />
  """
  attr :user, :map, required: true
  attr :show_email, :boolean, default: true
  attr :avatar_size, :string, values: ~w(xs sm md lg), default: "lg"
  attr :class, :any, default: nil

  def user_profile(assigns) do
    ~H"""
    <div class={["flex items-center gap-3", @class]}>
      <.user_avatar user={@user} size={@avatar_size} />
      <div>
        <p class="font-semibold">{@user.name}</p>
        <p :if={@show_email} class="text-sm text-base-content/80">{@user.email}</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-4">
      <label>
        <span :if={@label} class="label mb-2 font-display text-base-content">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class ||
              "w-full input bg-base-100 border-2 border-primary/30 rounded-lg font-body focus:border-primary focus:ring-2 focus:ring-primary/20",
            @errors != [] && (@error_class || "input-error border-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(UploadWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(UploadWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
