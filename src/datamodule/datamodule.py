# src/datamodule/datamodule.py

from pathlib import Path
import pandas as pd
from typing import Optional
import torch
from torch.utils.data import DataLoader, Dataset
import pytorch_lightning as pl
from albumentations import (
    HorizontalFlip, Rotate, RandomBrightnessContrast, Compose, Resize, Normalize, RandomScale
)
from albumentations.pytorch import ToTensorV2
from PIL import Image
import numpy as np
from sklearn.model_selection import train_test_split


class ImageDataset(Dataset):
    def __init__(self, image_paths, labels, transform=None):
        self.image_paths = image_paths
        self.labels = labels
        self.transform = transform

    def __len__(self):
        return len(self.image_paths)

    def __getitem__(self, idx):
        image = Image.open(self.image_paths[idx]).convert("RGB")
        image = np.array(image)

        if self.transform:
            augmented = self.transform(image=image)
            image = augmented['image']

        if image.dtype != torch.float32:
            image = image.float()

        label = self.labels[idx]
        return image, label


class ImageDataModule(pl.LightningDataModule):
    def __init__(self, data_dir: str, batch_size: int = 32, num_workers: int = 4, img_size: int = 224,
                 augmentations: dict = None):
        super().__init__()
        self.data_dir = Path(data_dir)
        self.batch_size = batch_size
        self.num_workers = num_workers
        self.img_size = img_size
        self.augmentations = augmentations

    def prepare_data(self):
        pass

    def setup(self, stage: Optional[str] = None):
        data = []
        class_names = sorted([d.name for d in self.data_dir.iterdir() if d.is_dir() and d.name.isdigit()])
        class_to_idx = {cls_name: int(cls_name) - 1 for cls_name in class_names}  # Классы с 0

        for cls in class_names:
            cls_dir = self.data_dir / cls
            for embryo_dir in cls_dir.iterdir():
                if embryo_dir.is_dir():
                    for img_file in embryo_dir.iterdir():
                        if img_file.is_file() and img_file.suffix.lower() in ['.png', '.jpg', '.jpeg']:
                            data.append({"path": str(img_file), "label": class_to_idx[cls]})

        df = pd.DataFrame(data)
        train_df, val_df = train_test_split(df, test_size=0.2, stratify=df['label'], random_state=42)

        self.train_dataset = ImageDataset(
            image_paths=train_df['path'].tolist(),
            labels=train_df['label'].tolist(),
            transform=self.get_train_transforms()
        )

        self.val_dataset = ImageDataset(
            image_paths=val_df['path'].tolist(),
            labels=val_df['label'].tolist(),
            transform=self.get_val_transforms()
        )

    def get_train_transforms(self):
        transform = Compose([
            Resize(self.img_size, self.img_size),
            HorizontalFlip(p=self.augmentations.get("horizontal_flip", 0.5)),
            Rotate(limit=self.augmentations.get("rotation", 15), p=0.5),
            RandomBrightnessContrast(
                brightness_limit=self.augmentations.get("brightness", 0.2),
                contrast_limit=self.augmentations.get("contrast", 0.2),
                p=0.5
            ),
            # Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
            ToTensorV2()
        ])
        return transform

    def get_val_transforms(self):
        transform = Compose([
            Resize(self.img_size, self.img_size),
            # Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
            ToTensorV2()
        ])
        return transform

    def train_dataloader(self):
        return DataLoader(
            self.train_dataset, batch_size=self.batch_size, shuffle=True,
            num_workers=self.num_workers, pin_memory=True,
            persistent_workers=True
        )

    def val_dataloader(self):
        return DataLoader(
            self.val_dataset, batch_size=self.batch_size, shuffle=False,
            num_workers=self.num_workers, pin_memory=True,
            persistent_workers=True
        )
