# 🌶️ Tabasco 🌶️

Tabasco is an opinionated page-object framework designed to anchor your system tests in stability, reducing flakiness and simplifying navigation.

**Disclaimer**: this is an experimental project in its early stages of development. While it is not yet production-ready and may lack some polish, we are committed to improving it over time. We will strive to minimize breaking changes whenever possible, but please be aware that the project may evolve as we refine its features and functionality.

We welcome your feedback and contributions to help us spice things up! 🌶️

## Installation

## Usage

Within Tabasco, you can define either page objects or section objects. A page object is actually a special type of section, that defines a url and a visiting behavior, but they're inherently the same thing.

### A concrete example

We'll start with an example right away, showing how to define your first page:

```ruby
class DemoPage < Tabasco::Page
  attribute :customer_id
  attribute :tenant_id

  # A Page object is visitable, so it must define its URL
  # You can access attributes within the proc
  # Also accepts static strings directly e.g.: `url '/users/sign_in'`
  url { "/demo/#{customer_id}" }

  # By convention, page objects will also need to define a test id to locate a
  # DOM element that contains the page. The DOM element must have a data-testid
  # attribute with the value "root-container" (the framework translates underscores
  # to hyphens for you)
  container_test_id :root_container

  # Every page must define how we can verify it has been loaded
  # Verifying visible aspects of a page (that a user would identify) are present
  # If this returns a falsy value or raise an exception, the test will halt.
  # This is one of the guardrails the framework adds for you, as not verifying content
  # has been properly loaded is a common source of flakiness.
  ensure_loaded { has_content!('Welcome to the Demo Page') }

  # A page should be broken down in multiple subsections. The section DSL allows the
  # definition of inline sections quite easily, encouraging you to break down your
  # page onto smaller chunks from the start.
  # A DOM element with a matching testid must exist, can be customized with a test_id: argument.
  section :header do     # [data-testid="header"]
    # When defining sections this way (inline), you may omit the ensure_loaded block,
    # but it's recommended you specify it at least for your most important sections.
    # The framework will automatically verify your page and sections have loaded properly
    # for you.
    section :title do    # [data-testid="header"] [data-testid="title"]
      ensure_loaded { has_content!("Welcome to the demo page") }
    end

    section :menu do	 # [data-testid="header"] [data-testid="menu"]
      # Declare methods within a section to wrap access to DOM elements
      # and provide higher level APIs
      def navigate_to_contact_page
        # The Capybara DSL is automatically scoped to the innermost section for you.
        # So what looks like a pretty unspecific scope is actually quite granular.
        # This is another guardrail the framework adds for you ;)
        # The find call below equals to:
        # find('[data-testid="header"] [data-testid="menu"] a:last-child')
        find("a:last-child").click
      end
    end
  end

  # Breaking pages down into subsections can foster code reuse. Extracting your section
  # definition into a separate class is possible, and encouraged when your section belongs
  # too complex or when it needs to be reused in multiple places.
  # If your section is supposed to be reused exclusively within the context of another page
  # or section, we encourage you to namespace it under that page/section (in this case, DemoPage :)
  section :main_content, DemoPage::MainContent

  section :footer, test_id: :footer_section do
    # Attributes defined in the page are propagated automatically to all
    # inline sections (customer_id in this case). For sections defined as classes,
    # only arguments explicitly declared in the section class are propagated.
    ensure_loaded { has_content!(customer_id) }

    def open_terms_of_use_modal
      find("a:last-child").click
    end
  end

  def navigate_to_contact_page
    # we're referring to the menu section, and calling the
    # #navigate_to_contact_page method we defined earlier inside it
    menu.navigate_to_contact_page

    # A good practice: methods that navigate to a different page by clicking links
    # already return a page object representing the new page
    # Calling #load will already run the ensure_loaded block of this new page,
    # so this page object does not need to know implementation details of other pages
    ContactPage.load(customer_id:, tenant_id:) # ContactPage has been defined somewhere
  end
end
```

Note the convention around the verbs visit and navigate:

- We use **visit** when a user accesses the URL of a page directly.
- We say a user **navigates** from a page to another page, when they click a link or perform another action that redirects them.

If the above file is saved as `spec/pages/demo_page.rb`, you should define a `spec/pages/demo_page_spec.rb` that implements the actual tests for the features/behavior under test:

```ruby
# Use the page object itself as argument to describe, instead of arbitrary strings
RSpec.describe DemoPage do
  subject(:demo_page) { described_class.visit(customer_id:) }

  let(:customer_id) { ... }

  it "displays the contacts link" do
    # A getter method is added for each section you define
    # You can use page objects and sections as arguments to expect
    # And use the traditional Capybara DSL matchers you're used to. They'll behave as
    # expected, scoping the query to the section yin question
    expect(demo_page.title).to have_content("Welcome to the demo page")

    # section getters automatically yield the section itself if you pass a block
    # We encourage this pattern as a way to automatically chunk larger tests onto
    # logically coherent parts.
    demo_page.menu do |menu|
      expect(menu).to have_content("Home")
      expect(menu).to have_content("About us")
      expect(menu).to have_content("Contacts")
    end

    # We implemented #navigate_to_contact_page returning a new page object
    # This is a good practice, as the mere fact we returned it by calling #load
    # Will run the ensure_loaded logic of the new page.
    contact_page = demo_page.navigate_to_contact_page

    # Straightforward, we use the returned contact_page object to further interact
    # with the page. We haven't shown how this hypothetical ContactPage object
    # was implemented, but we assume it declared a :form section.
    contact_page.form do |form|
      expect(form).to have_field("Your name:")
      expect(form).to have_field("Your email:")
      expect(form).to have_field("Subject:")
    end
  end
end
```

### Section objects as classes

When your page object gets too complex or large, it might be useful to break it down into distinct files. While you can break your implementation down using Ruby mixins, the recommended approach is to identify complex sections and extract them as separate classes.

For instance, in the example above, we extracted a `spec/pages/demo_page/main_content.rb` that defines the section object `DemoPage::MainContent`. A possible implementation for this class would look like this:

```ruby
class DemoPage::MainContent < Tabasco::Section
  container_test_id :main_content # will match [data-testid="main-content"]

  attribute :customer_id

  # It is mandatory to explicitly define the logic for verifying that the
  # section has loaded
  ensure_loaded { has_content!('Your personalized offers') }

  # Arbitrary nesting of any types of section is possible
  section :title
  section :offers do
    # Other complex sections can be further nested
    section :calls_to_action, DemoPage::MainContentCTA
  end

  # Pages and Sections are encouraged to encapsulate DOM queries:
  # Spec files can use them through the RSpec expect interface:
  # expect(demo_page).to have_purchase_confirmation_message
  def has_purchase_confirmation_message?
    has_content?("Your purchase has been confirmed")
  end

  # Interaction methods start with an action verb
  def purchase_offer
    calls_to_action.click_button("Buy")

    self # returning self as a good practice to keep fluent api
  end
end
```

As you can see, it's pretty similar to a Page object. The main differences are that we inherit from a Section class, and, since sections aren't visitable, we can't define a url nor call the .visit static method. Generally speaking, it shouldn't be necessary for you to manually instantiate a section object, but if you need to do so, you have to call `.load` on it.

Note the section object defines the :customer_id attribute, but not :tenant_id. Even though the section is used within a page object that defines :tenant_id, it won't be available on the section object:

```ruby
demo_page.customer_id               # ok
demo_page.main_content.customer_id  # ok
demo_page.tenant_id                 # ok
demo_page.main_content.tenant_id    # NoMethodError
```

### Portal sections

Sometimes you'll need to bypass the automatic scoping of sections, and define a nested section that targets a DOM element that is not a children of the parent section container.

A common use case is for targeting the contents of floating elements, such as toast messages, datepickers, popover elements, that are often inserted close to the root of the page DOM.

For these cases, you can use portals. Consider the following html fragment:

```html
<div data-testid="toast-portal-container">This is a toast message!</div>

<div data-testid="my_form">...</div>
```

First, we give this portal a name and tell Tabasco how to find it:

```rb
Tabasco.configure do |config|
  # test_id is only necessary if it does not match the portal name
  config.portal(:toast_message, test_id: :toast_portal_container)
end
```

The `:toast_message` portal can now be used inside your sections:

```rb
class MyForm < Tabasco::Section
  container_test_id :my_form

  # ...

  portal :my_portal
end
```

The portal will behave as a subsection of MyForm, even though it's container is not a child of the form div:

```rb
my_form_section = MyForm.load
expect(my_form_section.portal).to have_content("My portal content!")

# Caveat: this won't work, as the DOM element is not copied or moved to the parent element!
expect(my_form_section).to have_content("My portal content!")
```

You may define multiple types of portals as well, but we encourage you to use this with caution, given bypassing the natural scoping of sections defeats the purpose of using Tabasco and reduces the amount of guardrails we can offer you out of the box.

```rb
Tabasco.configure do |config|
  config.portal(:toast_message, test_id: :portal_container)
  config.portal(:datepicker, test_id: :react_datepicker)
  config.portal(:popover, test_id: :my_popover_portal)
end
```

### Organizing your directory structure

Ideally, we want every page object to be co-located with their matching spec files. Page tests are placed in `spec/pages` (not `spec/system/pages`), and we encourage you to organize the directory structure following the navigational structure of your app. The goal is to make it intuitive to find the tests for a page by mirroring the navigation structure of your application.

As you further break down your page objects into concrete sections, you may also want to create matching \_spec files for the extracted section classes. This approach can help organize the tests for complex pages that wouldn't play nicely with a single spec file.

The following is a hypothetical example. In this case, the main dashboard page is divided into multiple tabs (reports, analytics, and so on...). Each tab could be owned by a different team, so their page objects and tests are separated. The dashboard page specs focus on ensuring the individual tabs can be navigated to correctly.

```
📁 spec/pages/dashboard/
| 📁 reports_page/
|  | 📁 filters_section/
|  |  |  💎 filters_section_spec.rb               # <= section object spec file
|  |  |  💎 filters_section.rb                    # <= section object
|  |  💎 reports_page_spec.rb                     # <= page spec file
|  |  💎 reports_page.rb                          # <= page page object
| 📁 analytics_page/
|  |  💎 analytics_page_spec.rb                   # <= page spec file
|  |  💎 analytics_page.rb                        # <= page page object
|  |
| 📁  (... other pages)
| 💎 dashboard_page_spec.rb                       # <= main page spec file
| 💎 dashboard_page.rb                            # <= main page object
```

Note that, although the tabs are technically in the same server-rendered page, we choose to treat each one as a standalone page object rather than a section object. Conceptually, the tabs are independent from each other, and they can also be accessed from a direct URL. For this reason, the dashboard page spec does very little, it basically just verifies we can navigate to the distinct pages:

```ruby
expect(dashboard_page.header).to have_content(user.name)

dashboard_page.navigate_to_analytics.tap do |page|
  expect(page).to be_present
end

dashboard_page.navigate_to_reports.tap do |page|
  expect(page).to be_present
end

# ...
```

Each of the above navigate_X methods return a page object that represents the target page we're navigating to. Their ensure_loaded block already handles verifying the navigation has been successful, so there isn't much else we need to do here. This is nice example of how page objects can be used to segregate responsibilities across the board, while also making our tests more stable by automatically embedding the verification of page preconditions for us.

The lines `expect(page).to be_present` are pretty much a NOOP, and we've only added them to better convey the intention behind the tests.

## Development

Clone the repository, install the dependencies and run the tests with bundle exec rspec.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/oysterhr/tabasco. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/oysterhr/tabasco/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Tabasco project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/oysterhr/tabasco/blob/main/CODE_OF_CONDUCT.md).
