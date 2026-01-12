
import re
from playwright.sync_api import sync_playwright, expect

def test_tooltip_dismissal():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Use mobile view
        context = browser.new_context(viewport={'width': 375, 'height': 667}, is_mobile=True)
        page = context.new_page()

        print("Navigating to research page...")
        page.goto("http://localhost:8000/research.html")

        # Wait for content to load
        page.wait_for_selector(".hover-image")

        # Locate the first tooltip target
        tooltip_target = page.locator(".hover-image").first

        print(f"Clicking tooltip target: {tooltip_target.inner_text()}")
        # Tap on the tooltip target
        tooltip_target.click()

        # Check if active class is added
        expect(tooltip_target).to_have_class(re.compile(r"active"))
        print("Tooltip has 'active' class.")

        class_list = tooltip_target.get_attribute("class")
        print(f"Classes after click: {class_list}")

        # Take a screenshot showing the open tooltip
        page.screenshot(path="verification/before_dismiss.png")

        print("Clicking outside (on body)...")
        # Tap outside (on the body)
        page.locator("body").click(position={"x": 10, "y": 10})

        # Check if active class is removed
        expect(tooltip_target).not_to_have_class(re.compile(r"active"))
        print("Tooltip 'active' class removed.")

        class_list_after = tooltip_target.get_attribute("class")
        print(f"Classes after dismiss: {class_list_after}")

        # Check if the tooltip image is still visible
        tooltip_img = tooltip_target.locator(".hover-img")

        # We expect it to be HIDDEN after dismiss.
        # If the bug exists, it will remain visible.

        # Note: We check if the bounding box is non-zero or if style display is not none
        # Because we want to confirm the BUG, we check if it IS visible.

        bbox = tooltip_img.bounding_box()
        is_visible_visually = False
        if bbox:
            if bbox['width'] > 0 and bbox['height'] > 0:
                is_visible_visually = True

        print(f"Is tooltip visually visible after dismiss? {is_visible_visually}")

        page.screenshot(path="verification/after_dismiss.png")

        if is_visible_visually:
            print("FAILURE: Tooltip is still visible after dismiss!")
        else:
            print("SUCCESS: Tooltip is hidden after dismiss.")

        browser.close()

if __name__ == "__main__":
    test_tooltip_dismissal()
