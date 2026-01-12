
import re
from playwright.sync_api import sync_playwright, expect

def test_index_tooltip():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Use mobile view
        context = browser.new_context(viewport={'width': 375, 'height': 667}, is_mobile=True)
        page = context.new_page()

        print("Navigating to index page...")
        page.goto("http://localhost:8000/index.html")

        # Wait for content to load
        page.wait_for_selector(".hover-image")

        # Locate the map tooltip target
        # It's inside the text "look at this map"
        tooltip_target = page.locator(".hover-image", has_text="map")

        print(f"Clicking tooltip target: {tooltip_target.inner_text()}")
        # Tap on the tooltip target
        tooltip_target.click()

        # Check if active class is added
        expect(tooltip_target).to_have_class(re.compile(r"active"))
        print("Tooltip has 'active' class.")

        class_list = tooltip_target.get_attribute("class")
        print(f"Classes after click: {class_list}")

        # Check visibility
        tooltip_img = tooltip_target.locator(".hover-img")
        expect(tooltip_img).to_be_visible()
        print("Tooltip is visible.")

        # Tap outside
        page.locator("body").click(position={"x": 10, "y": 10})

        # Check if active class is removed
        expect(tooltip_target).not_to_have_class(re.compile(r"active"))
        print("Tooltip 'active' class removed.")

        # Check visibility - should be hidden
        expect(tooltip_img).not_to_be_visible()
        print("Tooltip is hidden after dismiss.")

        browser.close()

if __name__ == "__main__":
    test_index_tooltip()
