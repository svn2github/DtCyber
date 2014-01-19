/*--------------------------------------------------------------------------
**
**  Copyright (c) 2013, Tom Hunter (see license.txt)
**
**  Name: cyber_channel.c
**
**  Description:
**      CDC CYBER and 6600 channel PCI card driver.
**
**--------------------------------------------------------------------------
*/

/*
**  -------------
**  Include Files
**  -------------
*/
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/fs.h>
#include <linux/errno.h>
#include <linux/types.h>
#include <linux/proc_fs.h>
#include <linux/poll.h>
#include <linux/fcntl.h>
#include <linux/seq_file.h>
#include <linux/cdev.h>
#include <linux/interrupt.h>
#include <linux/jiffies.h>
#include <linux/delay.h>
#include <linux/wait.h>
#include <linux/pci.h>

#include <asm/io.h>
#include <asm/system.h>
#include <asm/uaccess.h>

#include "cyber_channel.h"

/*
**  -----------------
**  Private Constants
**  -----------------
*/
#define VENDOR_ID_CYBER     0x10EE
#define DEVICE_ID_CYBER     0x6018
#define DEVICE_NAME         "cyber_channel"

/*
**  -----------------------
**  Private Macro Functions
**  -----------------------
*/

/*
**  -----------------------------------------
**  Private Typedef and Structure Definitions
**  -----------------------------------------
*/

/*
**  ---------------------------
**  Private Function Prototypes
**  ---------------------------
*/
static int __init channel_init(void);
static void __exit channel_exit(void);
static int channel_open(struct inode *inode, struct file *file);
static int channel_release(struct inode *inode, struct file *file);
static int channel_ioctl(struct inode *inode, struct file *file, unsigned int cmd, unsigned long arg);
static int channel_probe(struct pci_dev *dev, const struct pci_device_id *id);
static void channel_remove(struct pci_dev *dev);

/*
**  ----------------
**  Public Variables
**  ----------------
*/

/*
**  Parameters which can be set at load time.
*/
int channel_major =   0;
int channel_minor =   0;

module_param(channel_major, int, S_IRUGO);
module_param(channel_minor, int, S_IRUGO);

module_init(channel_init);
module_exit(channel_exit);

MODULE_AUTHOR("Tom Hunter");
MODULE_DESCRIPTION("CDC 6600 channel FPGA PCI Driver");
MODULE_LICENSE("GPL");

/*
**  -----------------
**  Private Variables
**  -----------------
*/
static struct pci_device_id  pci_id_table[] =
    {
        {VENDOR_ID_CYBER, DEVICE_ID_CYBER, PCI_ANY_ID, PCI_ANY_ID, 0, 0, 0},
        {0}
    };

static struct pci_driver cyber_channel_driver =
    {
    .name       = DEVICE_NAME,
    .id_table   = pci_id_table,
    .probe      = channel_probe,
    .remove     = channel_remove
    };

static struct file_operations channel_fops =
    {
    .owner      = THIS_MODULE,
    .open       = channel_open,
    .release    = channel_release,
    .ioctl      = channel_ioctl
    };

static unsigned long pciBase = 0;
static unsigned long pciSize = 0;
static void __iomem *ioAddress = 0;
static struct cdev cdev;

/*
**--------------------------------------------------------------------------
**
**  Private Functions
**
**--------------------------------------------------------------------------
*/

/*--------------------------------------------------------------------------
**  Purpose:        Initialise driver via PCI framework
**
**  Parameters:     Name        Description.
**
**  Returns:        PCI framework return code.
**
**------------------------------------------------------------------------*/
static int __init channel_init(void)
    {
    return(pci_register_driver(&cyber_channel_driver));
    }

/*--------------------------------------------------------------------------
**  Purpose:        Terminate driver via PCI framework
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void __exit channel_exit(void)
    {
    pci_unregister_driver(&cyber_channel_driver);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Open device.
**
**  Parameters:     Name        Description.
**                  inode       pointer to inode
**                  file        pointer to file
**
**  Returns:        Zero on successful open, negative error number
**                  otherwise.
**
**------------------------------------------------------------------------*/
static int channel_open(struct inode *inode, struct file *file)
    {
    return(0);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Close device.
**
**  Parameters:     Name        Description.
**                  inode       pointer to inode
**                  file        pointer to file
**
**  Returns:        Zero on successful close, negative error number
**                  otherwise.
**
**------------------------------------------------------------------------*/
static int channel_release(struct inode *inode, struct file *file)
    {
    return(0);
    }

/*--------------------------------------------------------------------------
**  Purpose:        I/O control handler.
**
**  Parameters:     Name        Description.
**                  inode       pointer to inode
**                  file        pointer to file
**                  cmd         I/O request
**                  arg         argument for cmd
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static int channel_ioctl(struct inode *inode, struct file *file, unsigned int cmd, unsigned long arg)
    {
    IoCB io;

    switch (cmd) 
        {
    case IOCTL_FPGA_READ:
        copy_from_user(&io, (IoCB *)arg, sizeof(IoCB));
        io.data = readw(ioAddress + io.address);
        copy_to_user((IoCB *)arg, &io, sizeof(IoCB));
        break;

    case IOCTL_FPGA_WRITE:
        copy_from_user(&io, (IoCB *)arg, sizeof(IoCB));
        writew(io.data, ioAddress + io.address);
        break;
        }

    return(0);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Probe and initialisation.
**
**  Parameters:     Name        Description.
**                  dev         pointer to PCI device control block
**                  id          pointer to PCI device ID
**
**  Returns:        Zero on successful probe, negative error number
**                  otherwise.
**
**------------------------------------------------------------------------*/
static int channel_probe(struct pci_dev *dev, const struct pci_device_id *id)
    {
    int result;
    dev_t devNode;

    printk("Entering channel probe\n");

    /* 
    ** Get a dynamic major number unless directed otherwise at load time.
    */
    if (channel_major)
        {
        devNode = MKDEV(channel_major, channel_minor);
        result = register_chrdev_region(devNode, 1, DEVICE_NAME );
        }
    else
        {
        result = alloc_chrdev_region(&devNode, channel_minor, 1, DEVICE_NAME );
        channel_major = MAJOR(devNode);
        }

    if (result < 0)
        {
        printk(KERN_ERR DEVICE_NAME ": can't get major %d (%d)\n", channel_major, result);
        goto cleanup0;
        }

    printk("about to wake\n");
    /*
    **  Wake up device.
    */
    result = pci_enable_device(dev);
    if (result < 0)
        {
        printk(KERN_ERR DEVICE_NAME ": unable to enable the device\n");
        goto cleanup1;
        }

    printk("about to reserve\n");
    /*
    **  Reserve PCI I/O and memory resources.
    */
    result = pci_request_regions(dev, DEVICE_NAME);
    if (result < 0)
        {
        printk(KERN_ERR DEVICE_NAME ": unable to reserve PCI resources\n");
        goto cleanup2;
        }

    printk("about to map\n");
    /*
    **  Map device memory to kernel address space.
    */
    pciBase = pci_resource_start(dev, 0);
    pciSize = pci_resource_len(dev, 0);
    ioAddress = ioremap(pciBase, pciSize);
    if (ioAddress == NULL)
        {
        result = -1; // fix this
        printk(KERN_ERR DEVICE_NAME ": unable to map device memory - base=%lx, size=%ld\n", pciBase, pciSize);
        goto cleanup3;
        }

    printk("Base = %lX, size=%ld, addr=%p\n", pciBase, pciSize, ioAddress);

    /*
    ** Fill in the device driver control structure
    ** (this must be the last step)
    */
    cdev_init(&cdev, &channel_fops);
    cdev.owner = THIS_MODULE;
    cdev.ops = &channel_fops;
    result = cdev_add(&cdev, devNode, 1);
    if (result == 0)
        {
        goto cleanup0;
        }

    printk(KERN_ERR DEVICE_NAME ": cdev_add failed (%d)\n", result);
    iounmap(ioAddress);
cleanup3:
    pci_release_regions(dev);
cleanup2:
    pci_disable_device(dev);
cleanup1:
    unregister_chrdev_region(MKDEV(channel_major, channel_minor), 1);
cleanup0:
    printk("finished\n");
    return(result);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Remove driver and cleanup.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void channel_remove(struct pci_dev *dev)
    {
    iounmap(ioAddress);
    pci_release_regions(dev);
    pci_disable_device(dev);
    cdev_del(&cdev);
    unregister_chrdev_region(MKDEV(channel_major, channel_minor), 1);
    }

/*---------------------------  End Of File  ------------------------------*/

