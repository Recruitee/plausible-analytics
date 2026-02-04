defmodule PlausibleWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  This module provides a set of function components that can be used
  across the application.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: PlausibleWeb.Endpoint,
    router: PlausibleWeb.Router,
    statics: PlausibleWeb.static_paths()

  @doc """
  Renders the site header with logo.
  """
  attr :class, :string, default: nil

  def header(assigns) do
    ~H"""
    <nav class="relative z-20 py-8">
      <div class="container">
        <nav class="relative flex items-center justify-between sm:h-10 md:justify-center">
          <div class="flex items-center flex-1 md:absolute md:inset-y-0 md:left-0">
            <div class="flex items-center justify-between">
              <a href="https://plausible.io">
                <img
                  src={~p"/images/icon/plausible_logo_dark.png"}
                  class="h-8 w-auto sm:h-10 -mt-2 hidden dark:inline"
                  alt="Plausible logo"
                  loading="lazy"
                />
                <img
                  src={~p"/images/icon/plausible_logo.png"}
                  class="h-8 w-auto sm:h-10 -mt-2 inline dark:hidden"
                  alt="Plausible logo"
                  loading="lazy"
                />
              </a>
            </div>
          </div>
          <div class="absolute inset-y-0 right-0 flex items-center justify-end w-2/3 sm:w-auto">
          </div>
        </nav>
      </div>
    </nav>
    """
  end
end
