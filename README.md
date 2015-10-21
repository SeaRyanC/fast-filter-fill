# Fast Filter Fill

A Factorio mod for managing container filters, logistic requests, and maybe other stuff later.

## [Download Fast Filter Fill 0.5.0](https://github.com/SeaRyanC/fast-filter-fill/raw/master/releases/FastFilterFill_0.5.0.zip)

## Quickly Set Container Filters

When you have a filterable container open (e.g. Cargo Wagon), buttons will appear in the UI to help you manage the filter settings of the inventory of that container. These buttons basically work like their equivalents in Excel.

### Fill All
**Fill All** will set the filter of each inventory slot to be the contents of the first slot of the container, or the contents of the cursor stack if the player is holding something. If there are conflicting items in the container, those cells will be skipped and a message will be displayed.

![Fill All demo](https://raw.githubusercontent.com/SeaRyanC/fast-filter-fill/master/gifs/fill-all-1.gif)

### Fill Right
**Fill Right** copies the filter settings for each cell to the cell to the right. This is useful for setting up rows of inventory:

![Fill Right demo](https://raw.githubusercontent.com/SeaRyanC/fast-filter-fill/master/gifs/fill-right-1.gif)

### Fill Down
**Fill Down** is the same as **Fill Right**, but copies down. Both **Fill Right** and **Fill Down** fill starting at each item, so it's easy to make a split container by placing "anchor items" at the upper-left corners of the regions you want to define:

![Fill Right and Down demo](https://raw.githubusercontent.com/SeaRyanC/fast-filter-fill/master/gifs/fill-right-and-down.gif)

### Clear All
**Clear All** removes all filters from a container. No demo image because this is easy to understand.

### Set All
**Set All** sets the filter of each cell to its current contents.

## Manage Logistics Requests

**Note:** due to a bug in Factorio, you won't see the updated logistic request values until you re-open the chest. This has been fixed in 0.12.13; in the meantime a message will be issued each time to remind you that the logistic request values are not accurate.

![Request Management Screenshot](https://github.com/SeaRyanC/fast-filter-fill/blob/master/gifs/requests.gif)

### x2, x5, and x10
These buttons multiply the quantity of each logistic request by 2, 5, or 10.

### Fill
This button changes the logistic request values to the amount that would fill the chest while preserving the ratios of each item. For example, if you had logistic requests for 5 empty barrels and 5 full barrels (both of which have a stack size of 10) in a container of size 48, **Fill** would update the logistic request to 240 empty barrels and 240 full barrels.

### Blueprint
This button sets the logistic request values to the items required by a blueprint. The blueprint can either be held in the cursor, or in the first cell of the container.

# Future Development

List of things to do:

 * Support all filterable containers. This requires a change in the Factorio code; see http://www.factorioforums.com/forum/viewtopic.php?f=28&t=17071
 * Remove the message indicating that logistic requester chests have to be re-opened; see http://www.factorioforums.com/forum/viewtopic.php?f=30&t=17196
 * Use a better method of determining the size of a container
