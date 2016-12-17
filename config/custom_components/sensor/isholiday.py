"""
Sensor to check whether current date is a holiday.
"""
import asyncio
import logging

import voluptuous as vol

from homeassistant.components.sensor import PLATFORM_SCHEMA
from homeassistant.const import (STATE_ON, STATE_OFF, CONF_NAME)
import homeassistant.util.dt as dt_util
from homeassistant.helpers.entity import Entity
import homeassistant.helpers.config_validation as cv

_LOGGER = logging.getLogger(__name__)

REQUIREMENTS = ['holidays==0.5']

ALL_COUNTRIES = ['AU', 'AT', 'CA', 'CO', 'DK', 'DE', 'MX', 'NZ', 'ES',
                 'UK', 'US']
CONF_COUNTRY = 'country'
CONF_PROVINCE = 'province'
DEFAULT_NAME = 'Holiday Sensor'

PLATFORM_SCHEMA = PLATFORM_SCHEMA.extend({
    vol.Required(CONF_COUNTRY): vol.In(ALL_COUNTRIES),
    vol.Optional(CONF_PROVINCE, default=None): cv.string,
    vol.Optional(CONF_NAME, default=DEFAULT_NAME): cv.string,
})


@asyncio.coroutine
def async_setup_platform(hass, config, async_add_devices, discovery_info=None):
    """Setup the Holiday sensor."""

    import holidays

    name = config.get(CONF_NAME)

    country = None

    country = config.get(CONF_COUNTRY)
    obj_holidays = getattr(holidays, country)()

    province = config.get(CONF_PROVINCE)

    if province:
        if province not in obj_holidays.PROVINCES:
            _LOGGER.error('There is no province/state %s in country %s',
                          province, country)
            return False
        else:
            obj_holidays = getattr(holidays, country)(state=province)

    yield from async_add_devices([IsHolidaySensor(obj_holidays, name)], True)
    return True


class IsHolidaySensor(Entity):
    """Implementation of a Holiday sensor."""

    def __init__(self, obj_holidays, name):
        """Initialize the sensor."""
        self._name = name
        self._obj_holidays = obj_holidays
        self._state = None

    @property
    def name(self):
        """Return the name of the sensor."""
        return self._name

    @property
    def state(self):
        """Return the state of the device."""
        return self._state

    @asyncio.coroutine
    def async_update(self):
        """Get date and look whether it is a holiday."""

        self._date = dt_util.now()
        if self._date in self._obj_holidays:
            self._state = STATE_ON
        else:
            self._state = STATE_OFF
